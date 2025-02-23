pipeline {
    agent { label 'titra' }
    
    environment {
        METEOR_SERVER = "http://192.168.50.9:80"
    }
    
    stages {
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
