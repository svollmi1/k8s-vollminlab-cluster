pipeline {
    agent any

    environment {
        KUBECONFIG = credentials('jenkins-kubeconfig')  // Add a Kubernetes credential in Jenkins
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: env.BRANCH_NAME, url: 'https://github.com/my-org/my-repo.git'
            }
        }

        stage('Validate YAML') {
            steps {
                script {
                    sh 'yamllint -d "{extends: default, rules: {line-length: disable}}" . || exit 1'
                }
            }
        }

        stage('Validate Helm Charts') {
            steps {
                script {
                    sh 'helm lint helm/'  // Adjust path if needed
                }
            }
        }

        stage('Validate Kubernetes Manifests') {
            steps {
                script {
                    sh 'kubeval -d k8s/'  // Validate all Kubernetes manifests
                }
            }
        }

        stage('Kubernetes Dry-Run') {
            steps {
                script {
                    sh 'kubectl apply --dry-run=client -f k8s/'  // Ensure all k8s resources are valid
                }
            }
        }

        stage('Pull & Test Container Image') {
            steps {
                script {
                    def image = sh(script: "yq e '.spec.values.image.repository' helm/helmrelease.yaml", returnStdout: true).trim()
                    def tag = sh(script: "yq e '.spec.values.image.tag' helm/helmrelease.yaml", returnStdout: true).trim()
                    
                    if (image && tag) {
                        sh "docker pull ${image}:${tag}"
                        sh "docker run --rm ${image}:${tag} /bin/sh -c 'echo Image is valid'"
                    } else {
                        error("Image repository or tag not found in helmrelease.yaml")
                    }
                }
            }
        }

        stage('CI Passed Notification') {
            steps {
                script {
                    echo "✅ All tests passed. Open a PR for review and merge!"
                }
            }
        }
    }

    post {
        failure {
            script {
                echo "❌ CI failed. Check logs for details."
            }
        }
    }
}

