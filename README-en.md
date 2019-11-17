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
