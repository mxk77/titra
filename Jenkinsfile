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
            steps {
                script {
                    // Build the lint stage image using our Dockerfile from the repository root
                    def lintImage = docker.build("mxk77/titra:lint", "-f Dockerfile --target=lint .")
                    // Run a container to extract the ESLint report
                    sh '''
                    containerId=$(docker create mxk77/titra:lint)
                    docker cp $containerId:/app/reports/eslint-report.xml ${WORKSPACE}/reports/eslint-report.xml || true
                    docker rm $containerId
                    '''
                }
            }
            post {
                always {
                    // Publish the lint report to Jenkins
                    recordIssues tools: [checkStyle(pattern: 'reports/eslint-report.xml')]
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    // Build the test stage image using our Dockerfile from the repository root
                    def testImage = docker.build("mxk77/titra:test", "-f Dockerfile --target=test .")
                    // Run a container to extract the test results report
                    sh '''
                    containerId=$(docker create mxk77/titra:test)
                    docker cp $containerId:/app/reports/test-results.xml ${WORKSPACE}/reports/test-results.xml || true
                    docker rm $containerId
                    '''
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

        stage('Publish Release with gh') {
            when { branch 'master' }
            steps {
                script {
                    // Publish a release using GitHub CLI
                    withCredentials([string(credentialsId: 'github_token', variable: 'GH_TOKEN')]) {
                        def commit = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                        echo "Using commit: ${commit}"
                        
                        writeFile file: 'release-notes.md', text: "Release created by Jenkins for version v${APP_VERSION}"
                        
                        sh """
                            gh release create v${APP_VERSION} ../bundle.zip \\
                                --title "v${APP_VERSION}" \\
                                --notes "\$(cat release-notes.md)" \\
                                --target ${commit}
                        """
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