# eks-monitoring/outputs.tf

output "prometheus_service_name" {
  description = "Kubernetes service name for Prometheus"
  value       = "kube-prometheus-stack-prometheus"
}

output "grafana_service_name" {
  description = "Kubernetes service name for Grafana"
  value       = "kube-prometheus-stack-grafana"
}

output "monitoring_namespace" {
  description = "Namespace where monitoring tools are installed"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}