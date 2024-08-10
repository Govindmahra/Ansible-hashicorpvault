pipeline {
    agent any

    environment {
        AWS_CREDENTIALS_ID = 'aws_cred'   // AWS credentials ID
        TERRAFORM_REPO = 'https://github.com/Govindmahra/Hasicorp-vault.git'  // Terraform repo URL
        ANSIBLE_REPO = 'https://github.com/Govindmahra/Ansible-hashicorpvault.git'  // Ansible repo URL
        ANSIBLE_PLAYBOOK = 'vault.yml'    // Ansible playbook file
        INVENTORY_FILE = 'aws_ec2.yml'    // Ansible inventory file
        TERRAFORM_DIR = 'infra'           // Directory where Terraform code is located
        PRIVATE_KEY_FILE = '/var/lib/jenkins/infra/vault_key.pem'  // Path to the private key file
        BASTION_USER = 'ubuntu'   // Bastion host user
        AWS_POLICY_ARN = 'arn:aws:iam::448014237739:role/fullaccess'  // ARN of the policy to attach
        IAM_ROLE_NAME = 'fullaccess' // IAM role associated with the bastion instance
        AWS_DEFAULT_REGION = 'us-east-1'  // Default AWS region (set to your preferred region)
    }

    stages {
        stage('Checkout Terraform Code') {
            steps {
                git branch: 'main', url: "${TERRAFORM_REPO}"
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                    dir(TERRAFORM_DIR) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

                            terraform init
                        '''
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                    dir(TERRAFORM_DIR) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

                            terraform apply -auto-approve
                        '''
                        script {    
                            def bastionHost = sh(script: 'terraform output -raw public_instance_ip_out', returnStdout: true).trim()
                            echo "Bastion Host IP: ${bastionHost}"
                            env.BASTION_HOST = bastionHost
                        }
                    }
                }
            }
        }

        stage('Copy Key and Ansible Code to Bastion Host') {
            steps {
                script {
                    def bastionHost = env.BASTION_HOST

                    echo "Bastion Host IP for SCP: ${bastionHost}"

                    def keyExists = fileExists("${PRIVATE_KEY_FILE}")
                    if (!keyExists) {
                        error "Private key file not found: ${PRIVATE_KEY_FILE}"
                    }

                    // Copy the private key and required files to the bastion host
                    sh """
                        scp -o StrictHostKeyChecking=no -i ${PRIVATE_KEY_FILE} ${PRIVATE_KEY_FILE} ${BASTION_USER}@${BASTION_HOST}:/home/${BASTION_USER}/.ssh/
                        ssh -o StrictHostKeyChecking=no -i ${PRIVATE_KEY_FILE} ${BASTION_USER}@${BASTION_HOST} "
                            scp -o StrictHostKeyChecking=no -i ${PRIVATE_KEY_FILE} /home/${BASTION_USER}/.ssh/${PRIVATE_KEY_FILE} ${BASTION_USER}@${BASTION_HOST}:/home/${BASTION_USER}/
                            export PATH=\$PATH:/home/${BASTION_USER}/.local/bin &&
                            sudo apt-get update &&
                            sudo apt-get install -y python3 python3-pip &&
                            pip3 install --user boto boto3 botocore ansible &&
                            git clone ${ANSIBLE_REPO} /home/${BASTION_USER}/Ansible-hashicorpvault &&
                            cp -r /home/${BASTION_USER}/Ansible-hashicorpvault/vault_role /home/${BASTION_USER}/ &&
                            cp -r /home/${BASTION_USER}/Ansible-hashicorpvault/aws_ec2.yml /home/${BASTION_USER}/ &&
                            cp -r /home/${BASTION_USER}/Ansible-hashicorpvault/ansible.cfg /home/${BASTION_USER}/ &&
                            cp -r /home/${BASTION_USER}/Ansible-hashicorpvault/vault.yml /home/${BASTION_USER}/
                        "
                    """
                }
            }
        }

        stage('Attach IAM Role to Instance') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                        // Get the instance ID associated with the bastion host IP
                        def instanceId = sh(script: """
                            aws ec2 describe-instances \
                                --region ${AWS_DEFAULT_REGION} \
                                --filters "Name=ip-address,Values=${env.BASTION_HOST}" \
                                --query 'Reservations[0].Instances[0].InstanceId' \
                                --output text
                        """, returnStdout: true).trim()

                        // Attach IAM role to instance
                        sh(script: """
                            aws ec2 associate-iam-instance-profile \
                                --region ${AWS_DEFAULT_REGION} \
                                --instance-id ${instanceId} \
                                --iam-instance-profile Name=${IAM_ROLE_NAME}
                        """)
                        echo "IAM Role ${IAM_ROLE_NAME} attached to instance with IP ${env.BASTION_HOST}"
                    }
                }
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                script {
                    def bastionHost = env.BASTION_HOST

                    echo "Bastion Host IP for Ansible Playbook: ${bastionHost}"

                    sh """
                        ssh -o StrictHostKeyChecking=no -i ${PRIVATE_KEY_FILE} ${BASTION_USER}@${bastionHost} "/home/${BASTION_USER}/.local/bin/ansible-playbook /home/${BASTION_USER}/${ANSIBLE_PLAYBOOK} -i /home/${BASTION_USER}/${INVENTORY_FILE}"
                    """
                }
            }
        }
    }

    post {
        always {
            script {
                def destroy = input(id: 'userInput', message: 'Do you want to destroy the infrastructure?', parameters: [choice(name: 'confirm', choices: ['no', 'yes'], description: 'Choose yes to destroy, no to cancel.')])

                if (destroy == 'yes') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                        dir(TERRAFORM_DIR) {
                            sh '''
                                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

                                terraform destroy -auto-approve
                            '''
                        }
                    }
                }
            }
        }
    }
}


