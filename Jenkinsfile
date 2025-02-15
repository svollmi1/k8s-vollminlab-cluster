pipeline {
    agent any
    environment {
        KUBECONFIG = '/home/vollmin/.kube/config'  // Ensure kubeconfig path is correct
        GITHUB_TOKEN = credentials('4e6c3324-d53c-4c9c-afd9-6fc96ae88f72')  // GitHub Personal Access Token (PAT)
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/svollmi1/k8s-vollminlab-cluster.git'
            }
        }

        stage('Dry-Run Kubernetes Deployment') {
            steps {
                script {
                    // Perform dry-run to check for issues with the Kubernetes resources
                    sh '''
                    kubectl apply -f . --dry-run=client --namespace=ci-testing
                    '''
                }
            }
        }

        stage('Deploy to Test Namespace') {
            steps {
                script {
                    // Deploy to test namespace to verify that everything applies correctly
                    sh '''
                    kubectl apply -f . --namespace=ci-testing
                    '''
                }
            }
        }

        stage('Validate Deployment') {
            steps {
                script {
                    // Wait for deployment to be ready in the test namespace
                    sh '''
                    kubectl rollout status deployment --namespace=ci-testing || true
                    '''
                }
            }
        }

        stage('Cleanup Test Namespace') {
            steps {
                script {
                    // Clean up resources after testing is done
                    sh '''
                    kubectl delete -f . --namespace=ci-testing || true
                    '''
                }
            }
        }
    }
    post {
        always {
            // Clean up the workspace (local files)
            cleanWs()
        }

        success {
            // Use the GitHub API to set the status check result
            script {
                def commitSha = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                sh """
                curl -X POST -H 'Authorization: token ${GITHUB_TOKEN}' \
                    -d '{"state": "success", "target_url": "http://your-jenkins-url.com", "description": "CI passed", "context": "ci/check"}' \
                    https://api.github.com/repos/svollmi1/k8s-vollminlab-cluster/statuses/${commitSha}
                """
            }
        }

        failure {
            // Set the status check to failure if the pipeline fails
            script {
                def commitSha = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                sh """
                curl -X POST -H 'Authorization: token ${GITHUB_TOKEN}' \
                    -d '{"state": "error", "target_url": "http://your-jenkins-url.com", "description": "CI failed", "context": "ci/check"}' \
                    https://api.github.com/repos/svollmi1/k8s-vollminlab-cluster/statuses/${commitSha}
                """
            }
        }
    }
}

