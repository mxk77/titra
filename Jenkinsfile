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

    environment {
        METEOR_SERVER = "http://192.168.50.9:80"
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

        // Optionally run lint on all branches except master (or you can expand to exclude release/hotfix if desired)
        stage('Lint Code') {
            when {
                expression {
                    // Example: skip on master & release/hotfix
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
                    // Collect test results
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

        stage('Publish to GitHub Releases') {
            when {
                branch 'master'
            }
            steps {
                dir('titra') {
                    script {
                        def pkg = readJSON file: 'package.json'
                        def version = pkg.version
                        echo "Package version: ${version}"
                        
                        createGitHubRelease(
                            repository: 'mxk77/titra',
                            tag: "v${version}",
                            commitish: env.GIT_COMMIT,
                            name: "v${version}",
                            bodyText: "Release created by Jenkins for version v${version}",
                            draft: false,
                            prerelease: false,
                            credentialId: 'github_token'
                        )

                        
                        uploadGithubReleaseAsset(
                            repository: 'mxk77/titra',
                            tag: "v${version}",
                            commitish: env.GIT_COMMIT,
                            filePath: '../bundle.zip',
                            assetName: 'bundle.zip',
                            contentType: 'application/zip',
                            credentialId: 'github_token'
                        )
                    }
                }
            }
        }


        // Transfer bundle.zip via SSH to a remote server, for production only (master or release/hotfix)
        stage('Transfer bundle.zip via SSH') {
            when {
                expression {
                    env.BRANCH_NAME == 'master' ||
                    env.BRANCH_NAME.startsWith('release/') ||
                    env.BRANCH_NAME.startsWith('hotfix/')
                }
            }
            steps {
                sshPublisher(publishers: [
                    sshPublisherDesc(
                        configName: 'RemoteAnsibleServer',
                        transfers: [
                            sshTransfer(
                                sourceFiles: 'bundle.zip',
                                remoteDirectory: '/artifacts/',
                                cleanRemote: true
                            )
                        ],
                        verbose: true
                    )
                ])
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