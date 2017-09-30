// https://github.com/jenkinsci/pipeline-model-definition-plugin/wiki/Syntax-Reference
// https://jenkins.io/doc/book/pipeline/syntax/#parallel
// https://jenkins.io/doc/book/pipeline/syntax/#post
pipeline {
    agent any
    environment {
        REPO = 'fjudith/limesurvey'
    }
    stages {
        stage ('Prepare') {
            steps {
                script {
                    if ("${BRANCH_NAME}" == "master"){
                        TAG = "latest"
                        NGINX = "nginx"
                        SLAVE = "slave"
                    }
                    else {
                        TAG = "${BRANCH_NAME}"
                        NGINX = "${BRANCH_NAME}-nginx"
                        SLAVE = "${BRANCH_NAME}-slave"
                    }
                }
                stash name: 'everything',
                      includes: '**'
            }
        }
        stage ('Docker build'){
            parallel {
                stage ('Limesurvey Apache server') {
                    agent { label 'docker'}
                    steps {
                        sh 'rm -rf *'
                        unstash 'everything'
                        sh 'tree -sh'
                        sh "docker build -f Dockerfile -t ${REPO}:${GIT_COMMIT} ."
                    }
                }
                stage ('Limesurvey Nginx server') {
                    agent { label 'docker'}
                    steps {
                        sh 'rm -rf *'
                        unstash 'everything'
                        sh 'tree -sh'
                        sh "docker build -f fpm/nginx/Dockerfile -t ${REPO}:${GIT_COMMIT}-nginx fpm/nginx/"
                    }
                }
                stage ('Limesurvey FPM server') {
                    agent { label 'docker'}
                    steps {
                        sh 'rm -rf *'
                        unstash 'everything'
                        sh 'tree -sh'
                        sh "docker build -f fpm/Dockerfile -t ${REPO}:${GIT_COMMIT}-fpm fpm/"
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
            archive "**/*"
        }
        unstable {
            echo 'Only run if the current Pipeline has an "unstable" status, usually caused by test failures, code violations, etc. Typically denoted in the web UI with a yellow indication.'
        }
        aborted {
            echo 'Only run if the current Pipeline has an "aborted" status, usually due to the Pipeline being manually aborted. Typically denoted in the web UI with a gray indication.'
        }
    }
}