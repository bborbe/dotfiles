
# kubectl
if type "kubectl" > /dev/null; then
	source <(command kubectl completion zsh)
fi

# kustomize
alias kustomize='command kubectl kustomize'

## Prevent direct kubectl usage - use environment-specific aliases instead
kubectl() {
	# Allow completion to work - check for __complete subcommand or completion context
	if [[ "$1" == "__complete" ]] || [[ "${funcstack[2]}" == _* ]]; then
		command kubectl "$@"
		return
	fi

	echo "ERROR: Please use environment-specific aliases instead:" >&2
	echo "  - kubectldev (development)" >&2
	echo "  - kubectlstaging (staging)" >&2
	echo "  - kubectlprod (production)" >&2
	echo "  - kubectlhell (hell)" >&2
	echo "  - kubectlquant (quant)" >&2
	return 1
}

# K8s switch context
#alias k8sdev="command kubectl config use-context gke_gce-smedia-k8s_europe-west3-c_dev"
#alias k8sstaging="command kubectl config use-context gke_gce-smedia-k8s_europe-west3-c_staging"
#alias k8sprod="command kubectl config use-context gke_gce-smedia-k8s_europe-west3-c_prod"
#alias k8shell="command kubectl config use-context hell"
#alias k8squant="command kubectl config use-context quant"

# Kubectl with context
alias kubectldev="command kubectl --context gke_gce-smedia-k8s_europe-west3-c_dev"
alias kubectlstaging="command kubectl --context gke_gce-smedia-k8s_europe-west3-c_staging"
alias kubectlprod="command kubectl --context gke_gce-smedia-k8s_europe-west3-c_prod"
alias kubectlhell="command kubectl --context hell"
alias kubectlquant="command kubectl --context quant"
