pipeline {
    agent { label params.AGENT_LABEL }
    
    parameters {
        string(name: 'AGENT_LABEL', defaultValue: 'titra', description: 'Agent label to run the build')
        string(name: 'NUM_BUILDS_TO_KEEP', defaultValue: '10', description: 'Number of builds to keep')
        string(name: 'BUILD_TIMEOUT', defaultValue: '20', description: 'Build timeout in minutes')
        string(name: 'LINT_IMAGE_NAME', defaultValue: 'mxk77/titra:lint', description: 'Docker image for linting')
        string(name: 'TEST_IMAGE_NAME', defaultValue: 'mxk77/titra:test', description: 'Docker image for testing')
        string(name: 'FINAL_IMAGE_BASE', defaultValue: 'mxk77/titra_app', description: 'Base Docker image name for the final image')
        string(name: 'REGISTRY_URL', defaultValue: 'https://index.docker.io/v1/', description: 'Docker registry URL')
        string(name: 'DOCKER_CRED', defaultValue: 'dockerhub-cred', description: 'Docker registry credentials ID')
        string(name: 'MASTER_BRANCH', defaultValue: 'master', description: 'Name of the master branch')
        string(name: 'RELEASE_REGEX', defaultValue: '^release/.*', description: 'Regex pattern for release branches')
        string(name: 'HOTFIX_REGEX', defaultValue: '^hotfix/.*', description: 'Regex pattern for hotfix branches')
    }
    
    options {
        // Discard old builds to keep Jenkins clean
        buildDiscarder(logRotator(numToKeepStr: params.NUM_BUILDS_TO_KEEP))
        // Time out any build taking longer than the specified minutes
        timeout(time: params.BUILD_TIMEOUT as Integer, unit: 'MINUTES')
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
            when {
                expression { 
                    // Run lint only if branch is not master, release, or hotfix
                    !(env.BRANCH_NAME == params.MASTER_BRANCH || 
                      env.BRANCH_NAME ==~ params.RELEASE_REGEX || 
                      env.BRANCH_NAME ==~ params.HOTFIX_REGEX)
                }
            }
            steps {
                script {
                    def lintImage = docker.build(params.LINT_IMAGE_NAME, "-f Dockerfile --target=lint .")
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
            when {
                expression { 
                    // Run tests only if branch is not master, release, or hotfix
                    !(env.BRANCH_NAME == params.MASTER_BRANCH || 
                      env.BRANCH_NAME ==~ params.RELEASE_REGEX || 
                      env.BRANCH_NAME ==~ params.HOTFIX_REGEX)
                }
            }
            steps {
                script {
                    // Build the test stage image using our Dockerfile from the repository root
                    def testImage = docker.build(params.TEST_IMAGE_NAME, "-f Dockerfile --target=test .")
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
                    def finalImage = docker.build("${params.FINAL_IMAGE_BASE}:${env.APP_VERSION}", "-f Dockerfile --target=final .")
                    
                    // Push the image for master, release, or hotfix branches
                    if (env.BRANCH_NAME == params.MASTER_BRANCH || 
                        env.BRANCH_NAME ==~ params.RELEASE_REGEX || 
                        env.BRANCH_NAME ==~ params.HOTFIX_REGEX) {
                        docker.withRegistry(params.REGISTRY_URL, params.DOCKER_CRED) {
                            finalImage.push("${env.APP_VERSION}")
                            finalImage.push("latest")
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo "Build succeeded on branch: ${env.BRANCH_NAME}"
        }
        failure {
            echo "Build failed on branch: ${env.BRANCH_NAME}"
        }
    }
}