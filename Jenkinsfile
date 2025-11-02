pipeline {
    agent any
    environment {
        AWS_REGION = "ap-south-1"
        AWS_DEFAULT_REGION = "ap-south-1"
    }

    stages {
        stage('Terraform Init') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat "terraform init -upgrade"
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                bat "terraform validate"
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat "terraform plan"
                }
            }
        }

        stage('Apply VPC Module') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat 'terraform apply -target="module.vpc" -auto-approve'
                }
            }
        }

        stage('Apply EKS Module') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat 'terraform apply -target="module.eks" -auto-approve'
                }
            }
        }

        stage('Update Kubeconfig') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat "aws eks update-kubeconfig --region ap-south-1 --name aegonish-eks-cluster"
                }
            }
        }

        stage('Verify Nodes') {
            steps {
                bat "kubectl get nodes"
            }
        }

        stage('Apply IAM OpenID Connect Provider') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat 'terraform apply -target="aws_iam_openid_connect_provider.eks" -auto-approve'
                }
            }
        }

        stage('List OpenID Connect Providers') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat "aws iam list-open-id-connect-providers --region ap-south-1"
                }
            }
        }

        stage('Apply IAM Role Policy Attachment') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat 'terraform apply -target="aws_iam_role_policy_attachment.ebs_csi_attach" -auto-approve'
                }
            }
        }

        stage('List Attached Role Policies') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat "aws iam list-attached-role-policies --role-name aegonish-eks-cluster-ebs-csi-irsa --region ap-south-1"
                }
            }
        }

        stage('Apply IAM Module') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat 'terraform apply -target="module.iam" -auto-approve'
                }
            }
        }

        stage('Apply ECR Module') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat 'terraform apply -target="module.ecr" -auto-approve'
                }
            }
        }

        stage('Apply EBS CSI Driver Addon') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat 'terraform apply -target="aws_eks_addon.ebs_csi_driver" -auto-approve'
                }
            }
        }

        stage('Final Full Apply') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat "terraform apply -auto-approve"
                }
            }
        }

        stage('Verification Checklist') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    bat """
                    kubectl get nodes
                    kubectl get pods -n kube-system | findstr ebs
                    aws iam list-attached-role-policies --role-name aegonish-eks-cluster-ebs-csi-irsa --region ap-south-1
                    aws eks describe-addon --cluster-name aegonish-eks-cluster --addon-name aws-ebs-csi-driver --region ap-south-1 --query "addon.status"
                    """
                }
            }
        }
    }

    post {
        success {
            echo "EKS Cluster deployment complete!"
        }
        failure {
            echo "EKS Cluster deployment failed!"
        }
    }
}