pipeline {
    agent { label 'titra' }

    /////////////////////////////////////////////////////////////
    // Global pipeline options & environment
    /////////////////////////////////////////////////////////////
    options {
        // Skip automatic 'checkout scm'
        skipDefaultCheckout(true)
        // Discard old builds to keep Jenkins clean
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // Time out any build taking longer than 10 minutes
        timeout(time: 10, unit: 'MINUTES')
    }

    /////////////////////////////////////////////////////////////
    // Stages
    /////////////////////////////////////////////////////////////
    stages {

        stage('Checkout') {
            steps {
                script {
                    // Explicit checkout to subdirectory "titra"
                    checkout([
                        $class: 'GitSCM',
                        branches: scm.branches,
                        doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
                        extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'titra']],
                        userRemoteConfigs: scm.userRemoteConfigs
                    ])
                    
                    // Extract Version
                    dir('titra'){
                        def pkg = readJSON file: 'package.json'
                        env.APP_VERSION = pkg.version
                        echo "App version: ${env.APP_VERSION}"
                    }
                }
            }
        }

        stage('Load .env') {
            steps {
                script {
                    dir('titra'){
                        def props = readProperties file: '.env'
                        props.each { key, value ->
                            env[key] = value
                        }
                    }
                }
            }
        }

        stage('Install npm Dependencies') {
            steps {
                dir('titra') {
                    sh 'npm install'
                }
            }
        }

        stage('Lint Code') {
            when {
                expression {
                    !env.BRANCH_NAME.matches(/master|release\/.*|hotfix\/.*/)
                }
            }
            steps {
                dir('titra') {
                    sh 'npm run lint || true'
                }
            }
        }

        stage('Publish ESLint Report') {
            when {
                expression {
                    !env.BRANCH_NAME.matches(/master|release\/.*|hotfix\/.*/)
                }
            }
            steps {
                dir('titra') {
                    recordIssues tools: [checkStyle(pattern: 'reports/eslint-report.xml')]
                }
            }
        }

        stage('Test') {
            when {
                expression {
                    !env.BRANCH_NAME.matches(/master|release\/.*|hotfix\/.*/)
                }
            }
            steps {
                dir('titra') {
                    sh 'npm test'
                }
            }
            post {
                always {
                    dir('titra') {
                        junit 'reports/test-results.xml'
                    }
                }
            }
        }

        // Build the Meteor app on all branches
        stage('Build Meteor App') {
            steps {
                dir('titra') {
                    sh '''
                      meteor build "$WORKSPACE/output" \
                        --directory \
                        --server=${METEOR_SERVER}
                    '''
                }
            }
        }

        // Stage: Build Docker Compose App
        stage('Build Docker Compose App') {
            when {
                expression {
                    env.BRANCH_NAME == 'master' || 
                    env.BRANCH_NAME.startsWith('release/') ||
                    env.BRANCH_NAME.startsWith('hotfix/')
                }
            }
            steps {
                script {
                    // Re-checkout repository into the 'tirta' folder to ensure all files (including Dockerfile) are present
                    dir('tirta') {
                        checkout scm
                        // Debug: List all files, including hidden ones
                    }
                    dir('tirta'){
                        // Build the docker image, passing the current build number as a tag.
                        def appImage = docker.build("${env.DOCKER_USERNAME}/titra_app:${env.APP_VERSION}", "-f Dockerfile .")
                    
                        // Push the image to Docker Hub using Jenkins credentials
                        docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-cred') {
                            appImage.push("${env.APP_VERSION}")
                            appImage.push("latest")
                        }
                    }
                }
            }
        }

        // Compress artifacts only if on master, release, or hotfix
        stage('Compress Artifacts') {
            when {
                expression {
                    env.BRANCH_NAME == 'master' || 
                    env.BRANCH_NAME.startsWith('release/') ||
                    env.BRANCH_NAME.startsWith('hotfix/')
                }
            }
            steps {
                sh 'rm -f bundle.zip'
                zip zipFile: 'bundle.zip', dir: 'output/bundle', archive: true
            }
        }

        // Publish to GitHub Releases
        stage('Publish Release with gh') {
            when { branch 'master' }
            steps {
                script {
                    // Inject the GitHub token into the environment variable GH_TOKEN
                    withCredentials([string(credentialsId: 'github_token', variable: 'GH_TOKEN')]) {
                        // Switch to the titra directory where all files are present
                        dir('titra') {
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
    }

    /////////////////////////////////////////////////////////////
    // Post-block for final cleanup or notifications
    /////////////////////////////////////////////////////////////
    post {
        always {
            // Example: Clean workspace to avoid leftover artifacts
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