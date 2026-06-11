resource "kubernetes_namespace" "monitoring" {
    metadata {
        name = "monitoring"

        labels = {
          name        = "monitoring"
          environment = var.environment
        }
    }
}


resource "kubernetes_storage_class" "Monitoring_storage_class" {
    metadata {
        name = "monitoring-storage-class"
        annotations = {
          # This annotation is used by some provisioners to identify the default storage class.
          "storageclass.kubernetes.io/is-default-class" = "false"
        }
    }
    storage_provisioner = "kubernetes.io/aws-ebs"
    reclaim_policy = "retain"
    volume_binding_mode = "WaitForFirstConsumer"
    allow_volume_expansion = true       
    parameters = {
        type = "gp3"
        encrypted = "true"
        throughput = "125"
        iops = "5000"     
    }
}

resource "helm_release" "prometheus" {
    name = "kube-prometheus-stack"
    repository = "https://prometheus-community.github.io/helm-charts"
    chart = "kube-prometheus-stack"
    version = var.monitoring_version
    namespace = kubernetes_namespace.monitoring.metadata[0].name

    timeout = 600
    # 10 minutes — default 5 minutes is not enough

    # Wait for all pods to be ready before marking success
    wait = true

    # ── PROMETHEUS CONFIGURATION ──────────────────────────────

    set {
        name  = "prometheus.prometheusSpec.retention"
        value = "${var.prometheus_retention_days}d"
        # How long to keep metrics
        # After this period old metrics are deleted automatically
    }

    set {
        name  = "prometheus.prometheusSpec.retentionSize"
        value = "45GB"
        # Also delete old metrics if storage exceeds 45GB
        # Secondary safety net besides time based retention
    }

    set {
        name  = "prometheus.prometheusSpec.replicas"
        value = "2"
        # Run 2 Prometheus instances for HA
        # If one crashes, other keeps collecting metrics
        # Both scrape the same targets
        # Both store the same data (duplication is intentional)
    }

    set {
        name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
        value = "monitoring-gp3"
        # Use our custom storage class
    }

    set {
        name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
        value = var.prometheus_storage_size
        # 50GB EBS volume for Prometheus data
    }

    # Run Prometheus on system nodes
    set {
        name  = "prometheus.prometheusSpec.nodeSelector.role"
        value = "system"
    }

    # Tolerate system node taint
    set {
        name  = "prometheus.prometheusSpec.tolerations[0].key"
        value = "CriticalAddonsOnly"
    }

    set {
        name  = "prometheus.prometheusSpec.tolerations[0].value"
        value = "true"
    }

    set {
        name  = "prometheus.prometheusSpec.tolerations[0].effect"
        value = "NoSchedule"
    }

    # Resource limits for Prometheus pods
    set {
        name  = "prometheus.prometheusSpec.resources.requests.cpu"
        value = "500m"
    }

    set {
        name  = "prometheus.prometheusSpec.resources.requests.memory"
        value = "2Gi"
        # Prometheus is memory hungry
        # It keeps recent metrics in memory for fast queries
    }

    set {
        name  = "prometheus.prometheusSpec.resources.limits.cpu"
        value = "1000m"
    }

    set {
        name  = "prometheus.prometheusSpec.resources.limits.memory"
        value = "4Gi"
    }

    # ── GRAFANA CONFIGURATION ─────────────────────────────────

    set {
        name  = "grafana.adminPassword"
        value = var.grafana_admin_password
        # Admin password for Grafana UI login
        # Passed via TF_VAR_grafana_admin_password env var
    }

    set {
        name  = "grafana.replicas"
        value = "2"
        # 2 Grafana instances for HA
    }

    set {
        name  = "grafana.persistence.enabled"
        value = "true"
        # Enable persistent storage for Grafana
        # Without this, dashboards are lost on pod restart
    }

    set {
        name  = "grafana.persistence.storageClassName"
        value = "monitoring-gp3"
    }

    set {
        name  = "grafana.persistence.size"
        value = var.grafana_storage_size
        # 10GB for Grafana dashboards and settings
    }

    # Run Grafana on system nodes
    set {
        name  = "grafana.nodeSelector.role"
        value = "system"
    }

    set {
        name  = "grafana.tolerations[0].key"
        value = "CriticalAddonsOnly"
    }

    set {
        name  = "grafana.tolerations[0].value"
        value = "true"
    }

    set {
        name  = "grafana.tolerations[0].effect"
        value = "NoSchedule"
    }

    # Resource limits for Grafana
    set {
        name  = "grafana.resources.requests.cpu"
        value = "100m"
    }

    set {
        name  = "grafana.resources.requests.memory"
        value = "256Mi"
    }

    set {
        name  = "grafana.resources.limits.cpu"
        value = "200m"
    }

    set {
        name  = "grafana.resources.limits.memory"
        value = "512Mi"
    }

    # ── ALERTMANAGER CONFIGURATION ────────────────────────────

    set {
        name  = "alertmanager.alertmanagerSpec.replicas"
        value = "2"
        # 2 Alertmanager instances for HA
        # They coordinate to avoid duplicate alerts
    }

    set {
        name  = "alertmanager.alertmanagerSpec.resources.requests.cpu"
        value = "100m"
    }

    set {
        name  = "alertmanager.alertmanagerSpec.resources.requests.memory"
        value = "128Mi"
    }

    set {
        name  = "alertmanager.alertmanagerSpec.resources.limits.cpu"
        value = "200m"
    }

    set {
        name  = "alertmanager.alertmanagerSpec.resources.limits.memory"
        value = "256Mi"
    }

    # Run Alertmanager on system nodes
    set {
        name  = "alertmanager.alertmanagerSpec.nodeSelector.role"
        value = "system"
    }

    set {
        name  = "alertmanager.alertmanagerSpec.tolerations[0].key"
        value = "CriticalAddonsOnly"
    }

    set {
        name  = "alertmanager.alertmanagerSpec.tolerations[0].value"
        value = "true"
    }

    set {
        name  = "alertmanager.alertmanagerSpec.tolerations[0].effect"
        value = "NoSchedule"
    }

    # ── DEFAULT DASHBOARDS ────────────────────────────────────

    set {
        name  = "grafana.defaultDashboardsEnabled"
        value = "true"
        # Install pre-built Kubernetes dashboards automatically
        # Includes:
        # → Cluster overview dashboard
        # → Node metrics dashboard
        # → Pod metrics dashboard
        # → Namespace metrics dashboard
        # → Kubernetes API server dashboard
        # Zero configuration needed for these
    }

    depends_on = [
        kubernetes_namespace.monitoring,
        kubernetes_storage_class.monitoring
    ]
    }

    resource "kubernetes_manifest" "critical_alerts" {
    manifest = {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "PrometheusRule"

        metadata = {
          name      = "critical-alerts"
          namespace = kubernetes_namespace.monitoring.metadata[0].name
          labels = {
            # This label tells Prometheus to pick up this rule
             release = "kube-prometheus-stack"
             }
        }

        spec = {
        groups = [
            {
            name = "critical.rules"
            rules = [

                # Alert 1: Pod crash looping
                {
                alert = "PodCrashLooping"
                expr  = "rate(kube_pod_container_status_restarts_total[15m]) * 60 * 15 > 0"
                # If a pod restarted in the last 15 minutes
                for   = "5m"
                # Must be true for 5 continuous minutes
                # Prevents false alerts for single restarts
                labels = {
                    severity = "critical"
                }
                annotations = {
                    summary     = "Pod {{ $labels.pod }} is crash looping"
                    description = "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently"
                }
                },

                # Alert 2: Node not ready
                {
                alert = "NodeNotReady"
                expr  = "kube_node_status_condition{condition='Ready',status='true'} == 0"
                for   = "5m"
                labels = {
                    severity = "critical"
                }
                annotations = {
                    summary     = "Node {{ $labels.node }} is not ready"
                    description = "Node has been not ready for more than 5 minutes"
                }
                },

                # Alert 3: High memory usage on node
                {
                alert = "NodeHighMemoryUsage"
                expr  = "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85"
                for   = "10m"
                labels = {
                    severity = "warning"
                }
                annotations = {
                    summary     = "Node {{ $labels.instance }} memory usage above 85%"
                    description = "Node memory usage has been above 85% for 10 minutes"
                }
                },

                # Alert 4: Disk filling up
                {
                alert = "NodeDiskFillingUp"
                expr  = "(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100 > 80"
                for   = "15m"
                labels = {
                    severity = "warning"
                }
                annotations = {
                    summary     = "Node {{ $labels.instance }} disk usage above 80%"
                    description = "Node disk has been above 80% for 15 minutes"
                }
                },

                # Alert 5: Deployment not meeting desired replicas
                {
                alert = "DeploymentReplicasMismatch"
                expr  = "kube_deployment_spec_replicas != kube_deployment_status_available_replicas"
                for   = "10m"
                labels = {
                    severity = "warning"
                }
                annotations = {
                    summary     = "Deployment {{ $labels.deployment }} replica mismatch"
                    description = "Deployment has fewer available replicas than desired for 10 minutes"
                }
                }
            ]
            }
        ]
        }
    }

    depends_on = [helm_release.kube_prometheus_stack]
    }
