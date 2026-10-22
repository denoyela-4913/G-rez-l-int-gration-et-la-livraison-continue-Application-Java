{{/* Étiquettes communes à toutes les ressources du chart. */}}
{{- define "workshop-organizer.labels" -}}
app.kubernetes.io/name: workshop-organizer
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}
