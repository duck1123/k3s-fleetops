{{- define "dinsro.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version -}}
{{- end -}}

{{/* vim: set filetype=mustache: */}}
{{/*
 Expand the name of the chart.
 */}}
{{- define "dinsro.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{- define "dinsro.release" -}}
{{- .Release.Namespace | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
 Create a default fully qualified app name.
 We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
 */}}
{{- define "dinsro.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
