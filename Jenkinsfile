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
        
        stage('Build Meteor App') {
            steps {
                dir('titra') {
                    sh 'meteor build "$WORKSPACE/output" --directory --server=${METEOR_SERVER}'
                }
            }
        }

        stage('Transfer Artifacts via SSH') {
            steps {
                sshPublisher(publishers: [
                    sshPublisherDesc(
                        configName: 'RemoteAnsibleServer',
                        transfers: [
                            sshTransfer(
                                sourceFiles: 'output/bundle/**', 
                                removePrefix: 'output/bundle',
                                remoteDirectory: '/home/vagrant/bundle',
                            )
                        ],
                        verbose: true
                    )
                ])
            }
        }
        
        stage('Archive Build Artifacts') {
            steps {
                archiveArtifacts artifacts: 'output/bundle/**', fingerprint: true
            }
        }
    }
}
