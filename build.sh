set -e
function include_url_lib() {
  local t="$(mktemp)"
  local url="$1"
  curl -s -o "$t" "$1"
  . "$t"
  rm -f "$t"
}
function check_env(){
  local r
  for i do
    eval "r=\${${i}:-undefined}"
    if [ "$r" == "undefined" ];then
      echo "$i is not defined"
      exit 1
    fi
  done
}
ENV_CHECK_LIST='
REGISTRY_USER
REGISTRY_PASSWD
REGISTRY
REGISTRY_NAMESPACE
CI_COMMIT_TAG
CI_COMMIT_SHA
'
check_env $ENV_CHECK_LIST
docker login -u$REGISTRY_USER -p$REGISTRY_PASSWD $REGISTRY

function build_app(){
    local app_name=$1
    local pkg_prefix=$2
    local build_context=$3
    local dockerfile=${4:-Dockerfile}
    local image_url=$REGISTRY/$REGISTRY_NAMESPACE/${app_name}:${CI_COMMIT_SHA:0:8}
    docker build -f $dockerfile \
        --build-arg PKG_NAME=${pkg_prefix}-2.0.0-SNAPSHOT.jar \
        -t $image_url \
        $build_context
    docker push $image_url
}

APP_INFOS_FILE=/tmp/app-infos.txt
curl -s https://raw.githubusercontent.com/wanshare8888/tryme/master/biteme.txt -o $APP_INFOS_FILE

if [ "$CI_COMMIT_REF_NAME" == "master" ];then
  # 构建所有
  mvn -U clean package
  cat $APP_INFOS_FILE | grep -Ev '^#|crush-config-server' > build_list
  cat build_list | awk '{print $1,$3,$4}' | while read line;do
    build_app $line
  done
elif [ "$CI_COMMIT_REF_NAME" == "dev" ];then
  if echo "$CI_COMMIT_TAG" | grep -Eq "release-all";then
    # 构建所有
    mvn -U clean package
    cat $APP_INFOS_FILE | grep -Ev '^#|crush-config-server' | tee build_list | grep -v "crush-flyway" > deploy_list
    cat build_list | awk '{print $1,$3,$4}' | while read line;do
      build_app $line
    done
  else
    # 构建TAG中包含的模块
    # 根据TAG过滤出需要构建的列表 build_list
    O_IFS="$IFS"
    IFS="#"
    for i in $CI_COMMIT_TAG;do
        if app=$(grep "^$i[[:blank:]]" $APP_INFOS_FILE);then
            echo "$app" >> build_list
        fi
    done
    IFS="$O_IFS"

    if [ ! -s build_list ];then
        echo build_list size is 0, nothing to do.
        exit 1
    fi
    # 为mvn命令行构造模块列表参数
    mod_args=$(echo `awk '{print $2}' build_list` | tr ' ' ',')
    mvn clean package -U -pl $mod_args -am
    # 调用 build_app 完成 docker build 及 docker push
    awk '{print $1,$3,$4}' build_list | while read line;do
        build_app $line
    done

    awk '{print $1}' build_list | grep -Ev 'crush-config-server|crush-flyway' > deploy_list
  fi
fi