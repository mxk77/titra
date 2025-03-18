pipeline {
    agent { label 'titra' }

    options {
        // Discard old builds to keep Jenkins clean
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // Time out any build taking longer than 10 minutes
        timeout(time: 20, unit: 'MINUTES')
    }

    stages {
        stage('Extract Version') {
            steps {
                script {
                    // Extract version from package.json
                    def pkg = readJSON file: 'package.json'
                    env.APP_VERSION = pkg.version
                    echo "App version: ${env.APP_VERSION}"
                }
            }
        }

        stage('Lint') {
            // when {
            //     expression { !env.BRANCH_NAME.matches(/master|release\/.*|hotfix\/.*/) }
            // }
            steps {
                script {
                    def lintImage = docker.build("mxk77/titra:lint", "-f Dockerfile --target=lint .")
                    // Run commands inside a container – the container is automatically created and then cleaned up
                    lintImage.inside {
                        // Copy the report from the container's workspace to Jenkins workspace
                        sh 'cp /app/reports/eslint-report.xml ${WORKSPACE}/reports/eslint-report.xml || true'
                    }
                }
            }
            post {
                always {
                    recordIssues tools: [checkStyle(pattern: 'reports/eslint-report.xml')]
                }
            }
        }

        stage('Test') {
            // when {
            //     expression { !env.BRANCH_NAME.matches(/master|release\/.*|hotfix\/.*/) }
            // }
            steps {
                script {
                    // Build the test stage image using our Dockerfile from the repository root
                    def testImage = docker.build("mxk77/titra:test", "-f Dockerfile --target=test .")
                    // Run a container with the built image
                    testImage.inside {
                        // Copy the test results report to the Jenkins workspace
                        sh 'mkdir -p ${WORKSPACE}/reports && cp /app/reports/test-results.xml ${WORKSPACE}/reports/test-results.xml || true'
                    }
                }
            }
            post {
                always {
                    // Publish test results to Jenkins
                    junit 'reports/test-results.xml'
                }
            }
        }

        stage('Build Final Image') {
            steps {
                script {
                    // Build the final production image using our Dockerfile's final stage
                    def finalImage = docker.build("mxk77/titra_app:${env.APP_VERSION}", "-f Dockerfile --target=final .")
                    
                    // Push the image for master/release/hotfix branches
                    if (env.BRANCH_NAME == 'master' || env.BRANCH_NAME.startsWith('release/') || env.BRANCH_NAME.startsWith('hotfix/')) {
                        docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-cred') {
                            finalImage.push("${env.APP_VERSION}")
                            finalImage.push("latest")
                        }
                    }
                }
            }
        }

    }

    post {
        always {
            // Clean workspace after the build
            cleanWs()
        }
        success {
            echo "Build succeeded on branch: ${env.BRANCH_NAME}"
        }
        failure {
            echo "Build failed on branch: ${env.BRANCH_NAME}"
        }
    }
}