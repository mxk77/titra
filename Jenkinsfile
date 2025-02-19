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
                sh 'meteor build "$WORKSPACE/output" --directory --server=${METEOR_SERVER}'
            }
        }

        stage('Archive Build Artifacts') {
            steps {
                archiveArtifacts artifacts: 'output/bundle/**', fingerprint: true
            }
        }
    }
}
