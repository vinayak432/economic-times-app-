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
      image: dtzar/helm-kubectl:3.14.4
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
    IMAGE_TAG = "${BUILD_NUMBER}"

    CHART_DIR = "helm/helm-economic-times-app"
    CHART_NAME = "economic-times-app"

    JFROG_HOST = "trial1ttau5.jfrog.io"
    JFROG_REPO = "economic-times-app"
    JFROG_OCI = "oci://${JFROG_HOST}/${JFROG_REPO}"

    RELEASE_NAME = "economic-times-app"
    NAMESPACE = "default"
  }

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main',
            url: 'https://github.com/vinayak432/economic-times-app-.git'
      }
    }

    stage('Build Docker Image') {
      steps {
        container('docker') {
          sh '''
            docker version
            docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
            docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest
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
              echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
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
          sh '''
            sed -i 's|^version:.*|version: 0.1.${BUILD_NUMBER}|' ${CHART_DIR}/Chart.yaml
            sed -i 's|^appVersion:.*|appVersion: "${IMAGE_TAG}"|' ${CHART_DIR}/Chart.yaml
            echo "===== Updated Chart.yaml ====="
            cat ${CHART_DIR}/Chart.yaml
          '''
        }
      }
    }

    stage('Package Helm Chart') {
      steps {
        container('helmkubectl') {
          sh '''
            rm -rf packaged
            mkdir -p packaged
            helm version
            helm lint ${CHART_DIR}
            helm package ${CHART_DIR} -d packaged
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
              echo "${JFROG_PASS}" | helm registry login ${JFROG_HOST} -u "${JFROG_USER}" --password-stdin
              helm push packaged/${CHART_NAME}-0.1.${BUILD_NUMBER}.tgz ${JFROG_OCI}
            '''
          }
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        container('helmkubectl') {
          withCredentials([usernamePassword(
            credentialsId: 'jfrog-creds',
            usernameVariable: 'JFROG_USER',
            passwordVariable: 'JFROG_PASS'
          )]) {
            sh '''
              echo "${JFROG_PASS}" | helm registry login ${JFROG_HOST} -u "${JFROG_USER}" --password-stdin

              helm upgrade --install ${RELEASE_NAME} ${JFROG_OCI}/${CHART_NAME} \
                --version 0.1.${BUILD_NUMBER} \
                --namespace ${NAMESPACE} \
                --create-namespace \
                --set image.repository=${DOCKER_IMAGE} \
                --set image.tag=${IMAGE_TAG} \
                --wait \
                --timeout 5m

              echo "===== Verify Deployment ====="
              kubectl get pods -n ${NAMESPACE}
              kubectl get svc -n ${NAMESPACE}
              kubectl get deploy -n ${NAMESPACE}
            '''
          }
        }
      }
    }
  }

  post {
    always {
      container('helmkubectl') {
        sh 'helm registry logout ${JFROG_HOST} || true'
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
