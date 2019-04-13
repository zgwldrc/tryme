# 作者: 夏禹
# 邮箱: zgwldrc@163.com
# 运行环境: zgwldrc/maven-and-docker
# docker run --rm -it zgwldrc/maven-and-docker sh
# 该脚本用于crush项目在gitlab-ci系统中的构建
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

# 检查必要的环境变量
ENV_CHECK_LIST='
REGISTRY
REGISTRY_USER
REGISTRY_PASSWD
REGISTRY_NAMESPACE
DOCKERFILE_URL
APP_INFOS_URL
'
check_env $ENV_CHECK_LIST

docker version
docker login -u "$REGISTRY_USER" -p "$REGISTRY_PASSWD" "$REGISTRY"

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
    docker image rm $image_url
}

APP_INFOS_FILE=/tmp/app-infos.txt
curl -s "$APP_INFOS_URL" -o $APP_INFOS_FILE
curl -s "$DOCKERFILE_URL" -o Dockerfile
BUILD_EXCLUDE_LIST="${BUILD_EXCLUDE_LIST/,/|}"
DEPLOY_EXCLUDE_LIST="${DEPLOY_EXCLUDE_LIST/,/|}"
if echo "$CI_COMMIT_REF_NAME" | grep -Eq "release-all|dev" || [ "$BUILD_LIST" == "release-all" ] ;then
    # 构建所有
    mvn -U clean package
    cat $APP_INFOS_FILE | grep -Ev "^#|${BUILD_EXCLUDE_LIST:-NOTHINGTOEXCLUDE}" | tee build_list | grep -Ev "crush-flyway|${DEPLOY_EXCLUDE_LIST:-NOTHINGTOEXCLUDE}" | awk '{print $1}' > deploy_list
    cat build_list | awk '{print $1,$3,$4}' | while read line;do
        build_app $line
    done
else
    if [ "$CI_COMMIT_REF_NAME" != "master" ];then
        BUILD_LIST="$CI_COMMIT_REF_NAME"       
    fi
    # 构建TAG中包含的模块
    # 根据TAG过滤出需要构建的列表 build_list
    O_IFS="$IFS"
    IFS="#"
    for i in $BUILD_LIST;do
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
