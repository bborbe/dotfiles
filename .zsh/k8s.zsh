
# K8s switch context
alias k8sdev="kubectl config use-context gke_gce-smedia-k8s_europe-west3-c_dev"
alias k8sstaging="kubectl config use-context gke_gce-smedia-k8s_europe-west3-c_staging"
alias k8sprod="kubectl config use-context gke_gce-smedia-k8s_europe-west3-c_prod"
alias k8squant="kubectl config use-context quant"
alias k8shell="kubectl config use-context hell"
alias k8sfire="echo 'use k8squant'"

# Kubectl with content
alias kubectldev="kubectl --context gke_gce-smedia-k8s_europe-west3-c_dev"
alias kubectlstaging="kubectl --context gke_gce-smedia-k8s_europe-west3-c_staging"
alias kubectlprod="kubectl --context gke_gce-smedia-k8s_europe-west3-c_prod"
alias kubectlfire="kubectl --context fire"
alias kubectlhell="kubectl --context hell"
