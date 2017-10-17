// 
// https://github.com/jenkinsci/pipeline-model-definition-plugin/wiki/Syntax-Reference
// https://jenkins.io/doc/book/pipeline/syntax/#parallel
// https://jenkins.io/doc/book/pipeline/syntax/#post
pipeline {
    agent any
    environment {
        REPO = 'fjudith/limesurvey'
        PRIVATE_REPO = "${PRIVATE_REGISTRY}/${REPO}"
        DOCKER_PRIVATE = credentials('docker-private-registry')
    }
    stages {
        stage ('Checkout') {
            steps {
                script {
                    COMMIT = "${GIT_COMMIT.substring(0,8)}"

                    if ("${BRANCH_NAME}" == "master"){
                        TAG   = "latest"
                        NGINX = "nginx"
                        FPM   = "fpm"
                    }
                    else {
                        TAG   = "${BRANCH_NAME}"
                        NGINX = "${BRANCH_NAME}-nginx"
                        FPM   = "${BRANCH_NAME}-fpm"                     
                    }
                }
                sh 'printenv'
            }
        }
        stage ('LimeSurvey Web & Application server') {
            agent { label 'docker'}
            steps {
                sh "docker build -f ./Dockerfile -t ${REPO}:${COMMIT} ./"
            }
            post {
                success {
                    echo 'Tag for private registry'
                    sh "docker tag ${REPO}:${COMMIT} ${PRIVATE_REPO}:${TAG}"
                }
            }
        }
        stage ('Docker build Micro-Service') {
            parallel {
                stage ('Limesurvey Nginx'){
                    agent { label 'docker'}
                    steps {
                        sh "docker build -f fpm/nginx/Dockerfile -t ${REPO}:${COMMIT}-nginx fpm/nginx/"
                    }
                    post {
                        success {
                            echo 'Tag for private registry'
                            sh "docker tag ${REPO}:${COMMIT}-nginx ${PRIVATE_REPO}:${NGINX}"
                        }
                    }
                }
                stage ('LimeSurvey PHP-FPM') {
                    agent { label 'docker'}
                    steps {
                        sh "docker build -f fpm/Dockerfile -t ${REPO}:${COMMIT}-fpm fpm/"
                    }
                    post {
                        success {
                            echo 'Tag for private registry'
                            sh "docker tag ${REPO}:${COMMIT}-fpm ${PRIVATE_REPO}:${FPM}"
                        }
                    }
                }
            }
        }
        stage ('Run'){
            parallel {
                stage ('Monolith'){
                    agent { label 'docker' }
                    steps {
                        // Create Network
                        sh "docker network create limesurvey-mono-${BUILD_NUMBER}"
                        // Start database
                        sh "docker run -d --name 'mysql-${BUILD_NUMBER}' -e MYSQL_ROOT_PASSWORD=limesurvey -e MYSQL_USER=limesurvey -e MYSQL_PASSWORD=limesurvey -e MYSQL_DATABASE=limesurvey --network limesurvey-mono-${BUILD_NUMBER} amd64/mysql:5.6"
                        sleep 15
                        // Start application
                        sh "docker run -d --name 'limesurvey-${BUILD_NUMBER}' --link mysql-mono-${BUILD_NUMBER}:mysql --network limesurvey-mono-${BUILD_NUMBER} ${REPO}:${COMMIT}"
                        // Get container ID
                        script{
                            DOCKER_LIME    = sh(script: "docker ps -qa -f ancestor=${REPO}:${COMMIT}", returnStdout: true).trim()
                        }
                    }
                }
                stage ('Micro-Services'){
                    agent { label 'docker'}
                    steps {
                        // Create Network
                        sh "docker network create limesurvey-micro-${BUILD_NUMBER}"
                        // Start database
                        sh "docker run -d --name 'mariadb-${BUILD_NUMBER}' -e MYSQL_ROOT_PASSWORD=limesurvey -e MYSQL_USER=limesurvey -e MYSQL_PASSWORD=limesurvey -e MYSQL_DATABASE=limesurvey --network limesurvey-micro-${BUILD_NUMBER} amd64/mariadb:10.0"
                        sleep 15
                        // Start Memcached
                        sh "docker run -d --name 'memcached-${BUILD_NUMBER}' memcached"
                        // Start application micro-services
                        sh "docker run -d --name 'fpm-${BUILD_NUMBER}' --link mariadb-${BUILD_NUMBER}:mariadb --link memcached-${BUILD_NUMBER}:memcached --network limesurvey-micro-${BUILD_NUMBER} ${REPO}:${COMMIT}-fpm"
                        sh "docker run -d --name 'nginx-${BUILD_NUMBER}' --link fpm-${BUILD_NUMBER}:fpm --link memcached-${BUILD_NUMBER}:memcached --network limesurvey-micro-${BUILD_NUMBER} ${REPO}:${COMMIT}-nginx"
                        // Get container IDs
                        script {
                            DOCKER_FPM   = sh(script: "docker ps -qa -f ancestor=${REPO}:${COMMIT}-fpm", returnStdout: true).trim()
                            DOCKER_NGINX = sh(script: "docker ps -qa -f ancestor=${REPO}:${COMMIT}-nginx", returnStdout: true).trim()
                        }
                    }
                }
            }
        }
        stage ('Test'){
            parallel {
                stage ('Monolith'){
                    agent { label 'docker' }
                    steps {
                        sleep 180 
                        // internal
                        sh "docker exec 'limesurvey-${BUILD_NUMBER}' /bin/bash -c 'curl -i -X GET http://localhost:80'"
                        // External
                        sh "docker run --rm --network limesurvey-mono-${BUILD_NUMBER} blitznote/debootstrap-amd64:17.04 bash -c 'curl -i -X GET http://${DOCKER_LIME}:80'"
                    }
                    post {
                        always {
                            echo 'Remove mono stack'
                            sh "docker rm -f limesurvey-${BUILD_NUMBER}"
                            sh "docker rm -f mariadb-${BUILD_NUMBER}"
                            sh "docker network rm limesurvey-mono-${BUILD_NUMBER}"
                        }
                        success {
                            sh "docker login -u ${DOCKER_PRIVATE_USR} -p ${DOCKER_PRIVATE_PSW} ${PRIVATE_REGISTRY}"
                            sh "docker push ${PRIVATE_REPO}:${TAG}"
                        }
                    }
                }
                stage ('Micro-Services'){
                    agent { label 'docker'}
                    steps {
                        sleep 180
                        // Internal
                        sh "docker exec nginx-${BUILD_NUMBER} /bin/bash -c 'curl -i -X GET http://localhost:8080'"
                        // Cross Container
                        // External
                    }
                    post {
                        always {
                            echo 'Remove micro-services stack'

                            sh "docker rm -f nginx-${BUILD_NUMBER}"
                            sh "docker rm -f fpm-${BUILD_NUMBER}"
                            sh "docker rm -f memcached-${BUILD_NUMBER}"
                            sh "docker rm -f mariadb-${BUILD_NUMBER}"
                        }
                        success {
                            sh "docker login -u ${DOCKER_PRIVATE_USR} -p ${DOCKER_PRIVATE_PSW} ${PRIVATE_REGISTRY}"
                            sh "docker push ${PRIVATE_REPO}:${FPM}"
                            sh "docker push ${PRIVATE_REPO}:${NGINX}"
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            echo 'Run regardless of the completion status of the Pipeline run.'
        }
        changed {
            echo 'Only run if the current Pipeline run has a different status from the previously completed Pipeline.'
        }
        success {
            echo 'Only run if the current Pipeline has a "success" status, typically denoted in the web UI with a blue or green indication.'

        }
        unstable {
            echo 'Only run if the current Pipeline has an "unstable" status, usually caused by test failures, code violations, etc. Typically denoted in the web UI with a yellow indication.'
        }
        aborted {
            echo 'Only run if the current Pipeline has an "aborted" status, usually due to the Pipeline being manually aborted. Typically denoted in the web UI with a gray indication.'
        }
    }
}