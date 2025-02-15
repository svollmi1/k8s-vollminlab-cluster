pipeline {
    agent any
    environment {
        KUBECONFIG = "/home/vollmin/.kube/config" // Path to your kubeconfig
        TEST_NAMESPACE = "ci-testing"
        GITHUB_TOKEN = credentials('4e6c3324-d53c-4c9c-afd9-6fc96ae88f72') // Reference the GitHub Personal Access Token (PAT)
    }
    stages {
        stage('Checkout') {
            steps {
                // Checkout the code from GitHub
                checkout scm
            }
        }
        stage('Validate YAML') {
            steps {
                script {
                    // Validate YAML files using kubeval or yamllint
                    sh 'yamllint .'
                    sh 'kubeval . --kubernetes-version "1.21.0"'
                }
            }
        }
        stage('Check Image Changes') {
            steps {
                script {
                    // Check if any Dockerfiles or Helm charts have changed
                    def changedFiles = sh(script: 'git diff --name-only $GIT_PREVIOUS_COMMIT $GIT_COMMIT', returnStdout: true).trim().split("\n")
                    def imageChanges = changedFiles.find { it.contains('Dockerfile') || it.contains('helm') }
                    
                    if (imageChanges) {
                        echo "Image-related changes detected. Testing images."
                        // Only pull and test images if changes are detected
                        sh 'docker build -t my-image .'
                        sh 'docker push my-image'
                    } else {
                        echo "No image-related changes detected. Skipping image testing."
                    }
                }
            }
        }
        stage('Dry-run Kubernetes Resources') {
            steps {
                script {
                    // Dry-run all Kubernetes resources to validate them
                    sh "kubectl apply --dry-run=client -f ."
                }
            }
        }
        stage('Deploy to Test Namespace') {
            steps {
                script {
                    // Deploy to ci-testing namespace
                    sh "kubectl apply -f . --namespace=${TEST_NAMESPACE}"
                }
            }
        }
        stage('Test Deployments') {
            steps {
                script {
                    // Run your tests in ci-testing namespace here (e.g., using Helm or kubectl)
                    // Example test: check if pods are running
                    sh "kubectl get pods --namespace=${TEST_NAMESPACE}"
                }
            }
        }
        stage('Clean Up Test Namespace') {
            steps {
                script {
                    // Clean up test environment after the tests
                    sh "kubectl delete -f . --namespace=${TEST_NAMESPACE}"
                }
            }
        }
    }
    post {
        success {
            echo 'CI pipeline passed! Ready to merge.'
        }
        failure {
            echo 'CI pipeline failed. Please check the logs.'
        }
    }
}
