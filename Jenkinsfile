pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = 'aishani87'
        IMAGE_NAME      = 'lab12-node-app'
        DOCKER_BIN      = '"C:\\Users\\tuhi8\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin\\docker.exe"'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Docker Build & Tag') {
            steps {
                bat """
                    ${DOCKER_BIN} build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_NUMBER} -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest .
                """
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    bat """
                        ${DOCKER_BIN} login -u %DOCKER_USER% -p %DOCKER_PASS%
                        ${DOCKER_BIN} push ${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_NUMBER}
                        ${DOCKER_BIN} push ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Blue-Green Deploy') {
            steps {
                powershell """
                    .\\deploy.ps1 -ImageTag ${BUILD_NUMBER} -DockerHubUser ${DOCKER_HUB_USER}
                """
            }
        }
    }

    post {
        always {
            // Log out from Docker Hub for credential hygiene
            bat "${DOCKER_BIN} logout"
        }
    }
}