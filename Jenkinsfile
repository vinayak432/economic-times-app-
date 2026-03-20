pipeline {
  agent {
    kubernetes {
      cloud 'kubernetes'
      defaultContainer 'helmkubectl'
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: economic-times-pipeline-agent
spec:
  serviceAccountName: jenkins
  containers:
    - name: docker
      image: docker:27.0.3-cli
      command: ['cat']
      tty: true
      securityContext:
        privileged: true
        runAsUser: 0
      volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock

    - name: helmkubectl
      image: dtzar/helm-kubectl
      command: ['cat']
      tty: true

  volumes:
    - name: docker-sock
      hostPath:
        path: /var/run/docker.sock
        type: Socket
"""
    }
  }

  environment {
    DOCKER_IMAGE = "vinayak432/economic-times-app"
    IMAGE_TAG    = "${BUILD_NUMBER}"

    CHART_DIR  = "helm/helm-economic-times-app"
    CHART_NAME = "economic-times-app"

    JFROG_HOST = "trial1ttau5.jfrog.io"
    JFROG_REPO = "economic-times-app"
    JFROG_OCI  = "oci://${JFROG_HOST}/${JFROG_REPO}"

    RELEASE_NAME = "economic-times-app"
    NAMESPACE    = "default"
  }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  stages {

    stage('Checkout') {
      steps {
        git branch: 'jen-pod-k8s-agent',
            url: 'https://github.com/vinayak432/economic-times-app-.git'
      }
    }

    stage('Build Docker Image') {
      steps {
        container('docker') {
          sh '''
            echo "===== Docker Version ====="
            docker version

            echo "===== Build Docker Image ====="
            docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
            docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest

            echo "===== Local Docker Images ====="
            docker images | grep economic-times-app || true
          '''
        }
      }
    }

    stage('Push Docker Image') {
      steps {
        container('docker') {
          withCredentials([usernamePassword(
            credentialsId: 'docker-creds',
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
          )]) {
            sh '''
              echo "===== Docker Login ====="
              echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin

              echo "===== Push Docker Tags ====="
              docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
              docker push ${DOCKER_IMAGE}:latest

              docker logout || true
            '''
          }
        }
      }
    }

    stage('Update Chart Version') {
      steps {
        container('helmkubectl') {
          sh """
            echo "===== Chart.yaml BEFORE update ====="
            cat ${CHART_DIR}/Chart.yaml

            sed -i "s|^version:.*|version: 0.1.${BUILD_NUMBER}|" ${CHART_DIR}/Chart.yaml
            sed -i "s|^appVersion:.*|appVersion: \\"${IMAGE_TAG}\\"|" ${CHART_DIR}/Chart.yaml
            sed -i "s|^tag:.*|tag: \\"${IMAGE_TAG}\\"|" ${CHART_DIR}/values.yaml
            echo "===== Chart.yaml AFTER update ====="
            cat ${CHART_DIR}/Chart.yaml
          """
        }
      }
    }

    stage('Package Helm Chart') {
      steps {
        container('helmkubectl') {
          sh '''
            rm -rf packaged
            mkdir -p packaged

            echo "===== Helm Version ====="
            helm version

            echo "===== Helm Lint ====="
            helm lint ${CHART_DIR}

            echo "===== Package Helm Chart ====="
            helm package ${CHART_DIR} -d packaged

            echo "===== Packaged Helm Chart ====="
            ls -lh packaged
          '''
        }
      }
    }

    stage('Push Helm Chart to JFrog OCI') {
      steps {
        container('helmkubectl') {
          withCredentials([usernamePassword(
            credentialsId: 'jfrog-creds',
            usernameVariable: 'JFROG_USER',
            passwordVariable: 'JFROG_PASS'
          )]) {
            sh '''
              echo "===== Packaged Directory Contents ====="
              ls -lh packaged

              CHART_PACKAGE=$(ls packaged/*.tgz | head -n 1)

              if [ -z "${CHART_PACKAGE}" ]; then
                echo "ERROR: No .tgz chart package found in packaged/"
                exit 1
              fi

              echo "Using chart package: ${CHART_PACKAGE}"

              echo "===== Helm Registry Login (JFrog OCI) ====="
              echo "${JFROG_PASS}" | helm registry login ${JFROG_HOST} -u "${JFROG_USER}" --password-stdin

              echo "===== Push Helm Chart to JFrog OCI ====="
              helm push ${CHART_PACKAGE} ${JFROG_OCI}
            '''
          }
        }
      }
    }
  }

  post {
    always {
      container('helmkubectl') {
        sh '''
          helm registry logout ${JFROG_HOST} || true
        '''
      }
    }
    success {
      echo 'Pipeline completed successfully!'
    }
    failure {
      echo 'Pipeline failed. Check logs.'
    }
  }
}
