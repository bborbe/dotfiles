
# unset kubectl context
if type "kubectl" > /dev/null 2>&1; then
	command kubectl config unset current-context
fi

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

## Kubectl with isolated configs
kubectldev() { KUBECONFIG="${HOME}/.kube/octopus-dev" command kubectl "$@"; }
kubectlstaging() { KUBECONFIG="${HOME}/.kube/octopus-staging" command kubectl "$@"; }
kubectlprod() { KUBECONFIG="${HOME}/.kube/octopus-prod" command kubectl "$@"; }
kubectlhell() { KUBECONFIG="${HOME}/.kube/hell" command kubectl "$@"; }
kubectlquant() { KUBECONFIG="${HOME}/.kube/quant" command kubectl "$@"; }

# Set up completion for wrapper functions
if type "kubectl" > /dev/null 2>&1; then
	compdef kubectldev=kubectl
	compdef kubectlstaging=kubectl
	compdef kubectlprod=kubectl
	compdef kubectlhell=kubectl
	compdef kubectlquant=kubectl
fi
