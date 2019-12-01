![Flask example icon](/image.png)

### Flask RealWorld Example App x GitLab CI

[![pipeline status](https://gitlab.com/Willis0826/flask-realworld-example-app-ci-cd/badges/master/pipeline.svg)](https://gitlab.com/Willis0826/flask-realworld-example-app-ci-cd/commits/master)

[![coverage report](https://gitlab.com/Willis0826/flask-realworld-example-app-ci-cd/badges/master/coverage.svg)](https://gitlab.com/Willis0826/flask-realworld-example-app-ci-cd/commits/master)

English document is [here](./README-en.md)

本專案將介紹如何透過 GitLab CI，可以建置一個具有 Test、Pack、Cluster、Deploy 四個階段的 Pipeline 來進行持續整合與部屬(CI/CD)，專案使用的範例程式為 [flask-realworld-example-app](https://github.com/gothinkster/flask-realworld-example-app)，部屬運行的平台為 [GCE](https://cloud.google.com/compute/)，Docker image 發佈至 [Docker Hub](https://cloud.docker.com/repository/docker/willischou/flask-realworld-example-app/general)。

目錄

  - [GitLab CI and Environment](#gitlab-ci-and-environment)
  - [Pipeline Stage](#pipeline-stage)
    - [Test](#test)
    - [Pack](#pack)
    - [Cluster](#cluster)
    - [Deploy](#deploy)
  - [Promote to production](#promote-to-production)
  - [TODO](#todo)

#### GitLab CI and Environment

在開始 Pipeline 的運行前，需要於環境變數中提供 9個環境變數，GitLab CI 提供了相當方便的功能來設定，設定方法請參考 [Custom Environment Variables](https://docs.gitlab.com/ee/ci/variables/#custom-environment-variables)。

本專案的 Pipeline 將會依照是否有 Git Tags 來控制部署在 dev 與 prod 環境，所以，我們也需要先在 Gitlab Environment 建立對應的環境名稱，請參考 [Viewing environments and deployments](https://docs.gitlab.com/ee/ci/environments.html#working-with-environments)

建立好 dev 與 prod 兩個環境後，Gitlab 支援我們可以將 Environment Variables 與特定的 Environment 關聯在一起，使得 `.gitlab-ci.yaml` 當中可以使用 `environment` 欄位來決定套用的環境變數值。

以下列出本專案所有需要的環境變數：  

`環境變數名稱` **(環境範圍)** 描述

`DB_USER` **(dev, prod)** Postgres 資料庫使用者  
`DB_PASSWORD` **(dev, prod)** Postgres 資料庫密碼  
`K8S_CLUSTER_NAEM` **(dev, prod)** Kubernetes 叢集的名稱，使用於 kops 中  
`CONDUIT_SECRET` **(dev, prod)** flask app 使用的 secret key  
`DOCKER_REGISTRY_USER` **(all)** Docker Hub 的使用者名稱  
`DOCKER_REGISTRY_PASSWORD` **(all)** Docker Hub 的使用者密碼，需經過 base64 編碼  
`GCP_CREDENTIAL_FILE` **(all)** GCP 的服務帳號金鑰，如何產生金鑰請參考 [建立和管理服務帳戶金鑰](https://cloud.google.com/iam/docs/creating-managing-service-account-keys?hl=zh-tw)  
`KOPS_STATE_STORE` **(all)** Google storage bucket uri，用於儲存 kops 部署的叢集狀態  
`KOPS_FEATURE_FLAGS` **(all)** AlphaAllowGCE，允許 kops 在 GCP 上進行部署  

#### Pipeline Stage

##### Test

Test 階段，實作兩個工作進行單元測試(Unit Test)與風格檢查(Lint)。

GitLab runner 使用 `willischou/python-flask` [Docker Image](https://cloud.docker.com/repository/docker/willischou/python-flask)，其中包含 python 3.7 runtime，該 Docker Image 是由很簡單的 [Dockerfile](https://github.com/Willis0826/docker-base/blob/master/python-flask/Dockerfile) 建置。

單元測試(test.app)，安裝完成 python 套件後，執行時使用 `flask test` 進行測試，如果有錯誤，Pipeline 會在此階段中斷，因為單元測試是部署前的最低需求。

代碼檢查(lint.app)，安裝 flake8 套件，執行時使用 `flask lint` 進行 lint 工作，如果有錯誤，Pipeline 設定為可以接受錯誤，使 lint 產生的問題被紀錄後，繼續往下進行。

##### Pack

Pack 階段，進行 Docker build 的工作，將 flask app 透過 Dockerfile 包裝至 Docker image 中。

GitLab runner 使用 `docker:19.03.1`，並且[設定 Docker in Docker](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-in-docker-workflow-with-docker-executor)。

透過 `.ci/docker_pack.sh` 腳本，將依該次觸發 Pipeline 的 commit 是否有 tag 來決定使用環境變數 `$CI_COMMIT_SHORT_SHA` 或 `$CI_COMMIT_TAG` 當作 Docker image 的版本，提供我們在 dev 環境時，使用 git commit hash 來識別版本，於 prod 環境時，則使用更易於辨識的 git commit tag 當作版本。

另外於 Dockerfile 中，根據 Flask 的建議，先進行 [uwsgi](https://flask.palletsprojects.com/en/1.1.x/deploying/wsgi-standalone/#uwsgi) 套件的安裝，最終將 flask app 運行於 uwsgi 後面。

Database migration 的腳本在 `/migrations` 資料夾中，在 Docker image 建置的過程中，也會一併被打包，待後續的 K8S [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) 時執行 `flask db upgrade` 將 Postgres DB 進行升版。

##### Cluster

Cluster 階段，使用 Kops 依照 `/k8s/kops` 依序部署 cluster 與 instance group 在 GCP 上。

並使用環境變數中設定的 `KOPS_STATE_STORE` 來儲存 Kops 的狀態檔案與 `K8S_CLUSTER_NAEM` 指定叢集名稱。

該階段在叢集開始部署後，會進入一個迴圈等待叢集完成準備。

##### Deploy

Deploy 階段，將使用 Pack 階段產出的 Docker image 部署至 Kubernetes cluster。

GitLab runner 使用 `willischou/gcp-gomplate-kubectl` [Docker Image](https://cloud.docker.com/repository/dockerk/willischou/gcp-gomplate-kubectl)，其中包含進行 K8S 部署時所需的 kubectl、gcloud、gomplate、kops 等工具。

透過 `.ci/k8s_deploy.sh` 腳本，會先使用 [Gomplate](https://github.com/hairyhenderson/gomplate) 將 `/k8s/app`, `/k8s/postgres`, `k8s/nginx-ingress` 目錄底下的 yaml 檔案進行變數替換，接著使用 kubectl 進行部署；完成部署後，Ingress service IP 也將在 GitLab Pipeline `deploy.nginx-ingress` Job 中顯示。

可以透過以下三個步驟，測試 flask app 是否運作正常，本專案部署後 Ingress External IP 與 path 為 `35.202.214.124/flask/`。

1. 創建使用者 POST `35.202.214.124/flask/api/users` 設定 HTTP 標頭  `Content-Type: application/json` ，內容為

```json
{
    "user": {
        "username": "hello",
        "email": "dsa663838@gmail.com",
        "password": "abc12345"
    }
}
```

2. 創建文章 POST `35.202.214.124/flask/api/articles` 設定 HTTP 標頭 `Authorization: Token <jwt_token>`，內容為

```json
{
    "article": {
        "title": "Hi, flask app",
        "description": "How to deploy a flask app in minutes",
        "body": "First …"
    }
}
```

3. 查看文章 GET `35.202.214.124/flask/api/articles`，回應為

```json
{
    "articles": [
        {
            "author": {
                "bio": null,
                "email": "dsa663838@gmail.com",
                "following": false,
                "image": null,
                "username": "hello"
            },
            "body": "First …",
            "createdAt": "2019-10-19T10:20:59.198718",
            "description": "How to deploy a flask app in minutes",
            "favorited": false,
            "favoritesCount": 0,
            "slug": "hi-flask-app",
            "tagList": [],
            "title": "Hi, flask app",
            "updatedAt": "2019-10-19T10:20:59.198762"
        }
    ],
    "articlesCount": 1
}
```

#### Promote to production

透過 Gitlab 環境分出 dev 與 prod 兩個環境後，需要建立部署正式環境的機制，本專案設計為 Git commit 含有符合 v0.0.0 格式的 Tags 時，會觸發部署正式環境的工作。

![Pipeline](https://res.cloudinary.com/dqlglve8h/image/upload/v1575198777/repo-pipeline-prod_y9afuy.png)

#### TODO

本專案仍然有許多未實作的工作，以下將列舉並且說明。

1. 系統監控
Kubernetes cluster 系統監控，可以透過 Prometheus-operator 進行，並且搭配 Node-Exporter 取得叢集狀態，此專案使用的範例叢集已經完成該項部署，然而，因尚未部署 Grafana 至叢集中，待完成後，將會整理至獨立的 Repository，統一管理叢集相關資源。
Flask app 應用程式監控，可以通過 Middleware 進行採集並且送至 InfluxDB 等等時間序列資料庫，並由 Grafana 進行觀察與警示。
2. 建置與部署分離
本範例將 Pack 與 Deploy 兩個工作放在同一個 Repository 中呈現，是為了展示緣故；若同時擁有多個應用程式需要建置與部署，將部署工作抽出至另一個 Repository 中，統一管理應用程式部署與基礎架構，將降低部署相依性管理的複雜度，且優化 Infra as code 的代碼結構。
