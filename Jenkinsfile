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

        stage('Lint Code') {
            when {
                not {
                    branch 'master'
                }
            }
            steps {
                dir('titra') {
                    sh 'npm run lint'
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
                dir('titra') {
                    withCredentials([string(credentialsId: 'github_token', variable: 'GITHUB_TOKEN')]) {
                        script {
                            // Read package.json and extract version
                            def pkg = readJSON file: 'package.json'
                            def version = pkg.version
                            echo "Package version: ${version}"

                            // Build release payload and write it to a file to avoid inline interpolation
                            def releaseData = """{
                                "tag_name": "v${version}",
                                "target_commitish": "master",
                                "name": "v${version}",
                                "body": "Release created by Jenkins for version v${version}",
                                "draft": false,
                                "prerelease": false
                            }"""
                            writeFile file: 'releaseData.json', text: releaseData

                            // Create the GitHub release using a shell script that reads $GITHUB_TOKEN from the environment.
                            def createReleaseResponse = sh(script: '''#!/bin/bash
                                curl --silent --fail -X POST \\
                                -H "Authorization: token $GITHUB_TOKEN" \\
                                -H "Content-Type: application/json" \\
                                -d @releaseData.json \\
                                https://api.github.com/repos/mxk77/titra/releases
                            ''', returnStdout: true).trim()

                            // Parse the API response to extract the upload URL.
                            def releaseJson = readJSON text: createReleaseResponse
                            def uploadUrl = releaseJson.upload_url.replaceAll("\\{.*\\}", "")
                            echo "Upload URL: ${uploadUrl}"

                            // Upload the bundle.zip to the created release.
                            sh """#!/bin/bash
                            curl --fail -X POST \\
                                -H "Authorization: token \$GITHUB_TOKEN" \\
                                -H "Content-Type: application/zip" \\
                                --data-binary @../bundle.zip \\
                                "${uploadUrl}?name=bundle.zip"
                            """
                        }
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
