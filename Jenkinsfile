pipeline {
    agent { label 'titra' }
    
    options {
        skipDefaultCheckout()
    }
    
    environment {
        METEOR_SERVER = "http://192.168.50.9:80"
    }
    
    stages {

        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: scm.branches,
                    doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
                    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'titra']],
                    userRemoteConfigs: scm.userRemoteConfigs
                ])
            }
        }

        stage('Install npm Dependencies') {
            steps {
                dir('titra') {
                    sh 'npm install'
                }
            }
        }

        stage('Test') {
            when {
                not {
                    branch 'master'
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

        
        stage('Build Meteor App') {
            steps {
                dir('titra') {
                    sh 'meteor build "$WORKSPACE/output" --directory --server=${METEOR_SERVER}'
                }
            }
        }

        stage('Compress Artifacts') {
            when {
                branch 'master'
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
                // Ensure you have added your GitHub token as a Jenkins secret (e.g., "github_token")
                withCredentials([string(credentialsId: 'github_token', variable: 'GITHUB_TOKEN')]) {
                    script {
                        def pkg = readJSON file: 'package.json'
                        def version = pkg.version

                        // Build JSON payload for creating the release using the version from package.json
                        def releaseData = """
                        {
                            "tag_name": "v${version}",
                            "target_commitish": "master",
                            "name": "v${version}",
                            "body": "Release created by Jenkins for version v${version}",
                            "draft": false,
                            "prerelease": false
                        }
                        """

                        // Create a new GitHub release and capture the API response
                        def createReleaseResponse = sh(script: """
                            curl --silent --fail -X POST \\
                            -H "Authorization: token ${GITHUB_TOKEN}" \\
                            -H "Content-Type: application/json" \\
                            -d '${releaseData}' \\
                            https://api.github.com/repos/mxk77/titra/releases
                        """, returnStdout: true).trim()

                        // Parse JSON response to retrieve the upload URL.
                        def releaseJson = readJSON text: createReleaseResponse
                        def uploadUrl = releaseJson.upload_url.replaceAll("\\{.*\\}", "")
                        echo "Upload URL: ${uploadUrl}"

                        // Upload the bundle.zip to the created release.
                        sh """
                          curl --fail -X POST \
                          -H "Authorization: token ${GITHUB_TOKEN}" \
                          -H "Content-Type: application/zip" \
                          --data-binary @bundle.zip \
                          "${uploadUrl}?name=bundle.zip"
                        """
                    }
                }
            }
        }

        stage('Transfer bundle.zip via SSH') {
            when {
                branch 'master'
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
        /*
        stage('Archive Build Artifacts') {
            steps {
                archiveArtifacts artifacts: 'output/bundle/**', fingerprint: true
            }
        }*/
    }
}
