![GitHub Logo](/image.png)

### Flask RealWorld Example App x GitLab CI

[![pipeline status](https://gitlab.com/Willis0826/flask-realworld-example-app-ci-cd/badges/master/pipeline.svg)](https://gitlab.com/Willis0826/flask-realworld-example-app-ci-cd/commits/master)

The repository is going to introduce how to use GitLab CI to create a pipeline with Test, Pack, Cluster and Deploy stages, and the application used in the repository is [flask-realworld-example-app](https://github.com/gothinkster/flask-realworld-example-app). The Kubernetes cluster in running on [GCE](https://cloud.google.com/compute/), and the Docker image of application is published to [Docker Hub](https://cloud.docker.com/repository/docker/willischou/flask-realworld-example-app/general)

Directory

  - [GitLab CI and Environment](#gitlab-ci-and-environment)
  - [Pipeline Stage](#pipeline-stage)
    - [Test](#test)
    - [Pack](#pack)
    - [Cluster](#cluster)
    - [Deploy](#deploy)
  - [TODO](#todo)

#### GitLab CI and Environment

Before we start to run the pipeline, there are 9 environment variables should be set up in the GitLab CI. The instruction of set up environment variables can refer to [Custom Environment Variables](https://docs.gitlab.com/ee/ci/variables/#custom-environment-variables).

`CONDUIT_SECRET` The jwt secret key of flask app  
`DOCKER_REGISTRY_USER` The Docker Hub user name  
`DOCKER_REGISTRY_PASSWORD` The Docker Hub password with base64 encoded  
`GCP_CREDENTIAL_FILE` The GCP service account credential file. The instruction of create a service account and generate credential can refer to [Creating managing service account key](https://cloud.google.com/iam/docs/creating-managing-service-account-keys)  
`DB_USER` The Postgres DB user  
`DB_PASSWORD`  The Postgres DB password  
`K8S_CLUSTER_NAEM` The Kubernetes cluster name which is used by Kops to identify the cluster  
`KOPS_STATE_STORE` Google storage bucket uri which is used to store the cluster state created by Kops  
`KOPS_FEATURE_FLAGS` The value should be *AlphaAllowGCE* to enable the Kops create cluster on GCE  

#### Pipeline Stage

##### Test

On the test stage, there are two jobs unit test and lint. The jobs will check the qulity of code and perform basic unit test.

On the stage, we use `willischou/python-flask` [Docker Image](https://cloud.docker.com/repository/docker/willischou/python-flask) as GitLab runner image, the image provide python 3.7 runtime. It was built with a simple [Dockerfile](https://github.com/Willis0826/docker-base/blob/master/python-flask/Dockerfile).

For the unit test job(test.app), we install Python package first, and then run the command `flask test` to perform unit test. If there is any error, the pipeline will stop immediately. Because passing the unit test is required.

For the lint job(lint.app), we install flake8 package first, and then run the command `flask lint` to perform the linter. If there is any error, the pipeline will ignore the error and go on.

##### Pack

On the pack stage, we are going to build the Docker Image of flask app. For more detail, please check the Dockerfile.

On the stage, we use `docker:19.03.1` as GitLab runner image and [set up the Docker in Docker for GitLab runner](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-in-docker-workflow-with-docker-executor).

In the pack job, the sheel script `.ci/docker_pack.sh` will pack and tag the image according to the tag of commit or hash. If the commit has tag, the image tag will use environment variables `$CI_COMMIT_TAG` which is easy to recognize the version in prod. If the commit has no tag, the image tag will use `$CI_COMMIT_SHORT_SHA` which is generally use in dev.

According to the Flask app's recommandation, we install [uwsgi](https://flask.palletsprojects.com/en/1.1.x/deploying/wsgi-standalone/#uwsgi) package and running the flask app behind it.

Also, we pack the database migration script which is under `/migrations` folder alone with Docker image. The migration script will be performed via K8S [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/). After executed the command `flask db upgrade`, the Postgres DB will upgrade with latest database schema.

##### Cluster

On the cluster stage, we use Kops to deploy our Kubernetes cluster. The manifests for Kops are in `/k8s/kops` folder.

The stage require two environment varibles `KOPS_STATE_STORE` and `K8S_CLUSTER_NAEM`. `KOPS_STATE_STORE` is a google storage uri which store the cluster states created by Kops. `K8S_CLUSTER_NAEM` is the cluster name used to identify the cluster.

After the Kops successfully deployed the cluster, the shell script `.ci/kops_deploy.sh` will start a loop to validate the cluster status utill it is ready.

##### Deploy

On the deploy stage, we deploy the Docker image built from the pack stage to our Kubernetes cluster.

On the stage, we use `willischou/gcp-gomplate-kubectl` [Docker Image](https://cloud.docker.com/repository/dockerk/willischou/gcp-gomplate-kubectl) as GitLab runner image. The image contains the utils used for K8S deployment such as kubectl, gcloud, gomplate and kops.

In the shell script `.ci/k8s_deploy.sh`, we use [Gomplate](https://github.com/hairyhenderson/gomplate) to generate the completed manifest which are ready to be applied to the cluster. The manifest template are in the folder `/k8s/app`, `/k8s/postgres`, `k8s/nginx-ingress` and `/k8s/nginx-ingress`. After the manifest were generated, we use the kubectl to apply all the manifests. Finally, a nginx ingress service will be created, and the IP will be shown in the GitLab CI `deploy.nginx-ingress` job.

The nginx ingress external IP and path for this example is `34.67.218.129/flask/`. You can test the flask app by following the three steps below.

1. Create a user.  
POST `34.67.218.129/flask/api/users`  
HTTP Header  `Content-Type: application/json`  
HTTP Body  

```json
{
    "user": {
        "username": "hello",
        "email": "dsa663838@gmail.com",
        "password": "abc12345"
    }
}
```

2. Create a article  
POST `34.67.218.129/flask/api/articles`  
HTTP Header `Authorization: Token <jwt_token>`  
HTTP Body  

```json
{
    "article": {
        "title": "Hi, flask app",
        "description": "How to deploy a flask app in minutes",
        "body": "First …"
    }
}
```

3. Get all articles  
GET `34.67.218.129/flask/api/articles`  

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
