pipeline {
    
    agent any
    tools {
        maven "Maven"
    }
    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-cred')
        AWS_SECRET_ACCESS_KEY = credentials('aws-cred')
    }
    stages {
        stage("Chechout"){
            steps {
                git (
                    url: "https://github.com/prajaktag-20/maven-app.git",
                    branch: "main",
                    credentialsId: "github-cred"
                    
                    )
            }
        }
        
        stage("Build artifact"){
            steps {
                sh "mvn clean install -Dmaven.test.skip=true"
            }
            
        }
        
        
        stage("Build Image"){
            steps {
                sh "docker build -t app_v1 ."
            }
        }
        
        stage("Push Image"){
            steps{
                script{
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                    script {
                        sh '''
                        echo $PASSWORD | docker login -u $USERNAME --password-stdin
                        docker tag app_v1 p20repo/maven_app:${BUILD_NUMBER}
                        docker push p20repo/maven_app:${BUILD_NUMBER}
                        '''
                }
            }
        }
      }    
    }
    
        stage("Create Infra"){
            steps{
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-cred']]) {
               
                sh '''
                terraform init
                terraform plan
                terraform apply --auto-approve
                '''
                }
            }    
            
            
        }
  }    
}