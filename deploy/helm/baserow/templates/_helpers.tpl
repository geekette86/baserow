{{/*
Expand the name of the chart.
*/}}
{{- define "baserow.global.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "baserow.global.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .Values.global.baserow.fullnameOverride }}
{{- .Values.global.baserow.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
The domain the backend API is served on, "api.<domain>" when not set. When it
equals the frontend domain the API is served under that domain's /api/ path.
*/}}
{{- define "baserow.global.backendDomain" -}}
{{- .Values.global.baserow.backendDomain | default (printf "api.%s" .Values.global.baserow.domain) }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "baserow.global.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "baserow.global.labels" -}}
helm.sh/chart: {{ include "baserow.global.chart" . }}
{{ include "baserow.global.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "baserow.global.selectorLabels" -}}
app.kubernetes.io/name: {{ include "baserow.global.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create image url to use
*/}}
{{- define "baserow.global.image" -}}
{{- if and .Values.global.baserow.imageRegistry .Values.global.baserow.image.tag -}}
{{- printf "%s/%s:%s" .Values.global.baserow.imageRegistry .Values.image.repository .Values.global.baserow.image.tag }}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "baserow.global.serviceAccountName" -}}
{{- if .Values.global.baserow.serviceAccount.create }}
{{- default (include "baserow.global.fullname" .) .Values.global.baserow.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.global.baserow.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Create image url to use
*/}}
{{- define "baserow.global.migration.image" -}}
{{- if and .Values.global.baserow.imageRegistry .Values.global.baserow.image.tag -}}
{{- printf "%s/%s:%s" .Values.global.baserow.imageRegistry .Values.migration.image.repository .Values.global.baserow.image.tag }}
{{- else -}}
{{- printf "%s:%s" .Values.migration.image.repository .Chart.AppVersion }}
{{- end }}
{{- end }}

{{/*
Returns the available value for certain key in an existing secret (if it exists),
otherwise it generates a random value.
*/}}
{{- define "baserow.global.getValueFromSecret" }}
{{- $len := (default 16 .Length) | int -}}
{{- $obj := (lookup "v1" "Secret" .Namespace .Name).data -}}
{{- if $obj }}
{{- index $obj .Key | b64dec -}}
{{- else -}}
{{- randAlphaNum $len -}}
{{- end -}}
{{- end }}

{{/*
Get jwt secret name
*/}}
{{- define "baserow.global.jwt.secret_name" -}}
{{- printf "%s%s" (include "baserow.global.fullname" .) "-jwt"  -}}
{{- end }}

{{/*
Get jwt secret key
*/}}
{{- define "baserow.global.jwt.secret_key" -}}
{{- include "baserow.global.getValueFromSecret" (dict "Namespace" .Release.Namespace "Name" .Values.global.baserow.backendSecret "Length" 10 "Key" "SECRET_KEY")  -}}
{{- end }}


{{/*
Get jwt secret key
*/}}
{{- define "baserow.global.jwt.signing_key" -}}
{{- include "baserow.global.getValueFromSecret" (dict "Namespace" .Release.Namespace "Name" .Values.global.baserow.backendSecret "Length" 10 "Key" "BASEROW_JWT_SIGNING_KEY")  -}}
{{- end }}

{{/*
Create envFrom options
*/}}
{{- define "baserow.global.migration.envFrom" -}}
- configMapRef:
    name: {{ .Values.global.baserow.sharedConfigMap }}
- configMapRef:
    name: {{ .Values.global.baserow.backendConfigMap }}
- secretRef:
    name: {{ .Values.global.baserow.backendSecret }}
{{- if .Values.global.baserow.envFrom }}
{{ toYaml .Values.global.baserow.envFrom }}
{{- end }}
{{- if .Values.migration.envFrom }}
{{ toYaml .Values.migration.envFrom }}
{{- end }}
{{- end }}

{{/*
Get the password for the postgresql user
*/}}
{{- define "baserow.global.postgresql.password" -}}
  {{- if .Values.postgresql.enabled -}}
  {{- if .Values.postgresql.auth.existingSecret -}}
    {{- include "baserow.global.getValueFromSecret" (dict "Namespace" (include "common.names.namespace" .Subcharts.postgresql) "Name" (include "postgresql.v1.secretName" .Subcharts.postgresql) "Length" 10 "Key" (include "postgresql.v1.userPasswordKey" .Subcharts.postgresql))  -}}
  {{- else if .Values.postgresql.auth.password -}}
    {{ .Values.postgresql.auth.password }}
  {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Return the username for the postgres user
*/}}
{{- define "baserow.global.postgresql.username" -}}
  {{- if .Values.postgresql.enabled -}}
    {{ include "postgresql.v1.username" .Subcharts.postgresql }}
  {{- end -}}
{{- end -}}

{{/*
PodSecurityContext combine the global and local PodSecurityContexts
*/}}
{{- define "baserow.global.migration.podSecurityContext" -}}
{{- if .Values.migration.securityContext.enabled }}
{{- omit .Values.migration.securityContext "enabled" | toYaml  }}
{{- else if .Values.global.baserow.securityContext.enabled }}
{{- omit .Values.global.baserow.securityContext "enabled" | toYaml }}
{{- end }}
{{- end }}

{{/*
ContainerSecurityContext combine the global and local ContainerSecurityContexts
*/}}
{{- define "baserow.global.migration.containerSecurityContext" -}}
{{- if .Values.migration.containerSecurityContext.enabled }}
{{- omit .Values.migration.containerSecurityContext "enabled" | toYaml  }}
{{- else if .Values.global.baserow.containerSecurityContext.enabled }}
{{- omit .Values.global.baserow.containerSecurityContext "enabled" | toYaml }}
{{- end }}
{{- end }}

{{/*
Image used by the backup and restore jobs.
*/}}
{{- define "baserow.global.backup.image" -}}
{{- if and .Values.global.baserow.imageRegistry .Values.global.baserow.image.tag -}}
{{- printf "%s/%s:%s" .Values.global.baserow.imageRegistry .Values.backup.image.repository .Values.global.baserow.image.tag }}
{{- else -}}
{{- printf "%s:%s" .Values.backup.image.repository .Chart.AppVersion }}
{{- end }}
{{- end }}

{{/*
Environment of the backup and restore jobs, they need the same database settings as
the backend.
*/}}
{{- define "baserow.global.backup.envFrom" -}}
- configMapRef:
    name: {{ .Values.global.baserow.sharedConfigMap }}
- configMapRef:
    name: {{ .Values.global.baserow.backendConfigMap }}
- secretRef:
    name: {{ .Values.global.baserow.backendSecret }}
{{- if .Values.global.baserow.envFrom }}
{{ toYaml .Values.global.baserow.envFrom }}
{{- end }}
{{- if .Values.backup.envFrom }}
{{ toYaml .Values.backup.envFrom }}
{{- end }}
{{- end }}

{{/*
Renders a Helm hook Job that runs a database command of the backend image (backup or
restore) with the backup volume mounted at backup.persistence.mountPath.

Expects a dict with:
- root: the root context
- name: suffix of the job name and name of the container
- hook: the helm.sh/hook annotation value
- weight: the helm.sh/hook-weight annotation value
- args: the container arguments
*/}}
{{- define "baserow.global.backup.job" -}}
{{- $root := .root -}}
{{- $values := $root.Values.backup -}}
{{- if not (or $values.persistence.existingClaim $values.volumes) -}}
{{- fail "backup.persistence.existingClaim or backup.volumes must be set to store the backups outside of the job's pod" -}}
{{- end -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "baserow.global.fullname" $root }}-{{ .name }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "baserow.global.labels" $root | nindent 4 }}
  annotations:
    helm.sh/hook: {{ .hook }}
    helm.sh/hook-weight: {{ .weight | quote }}
    helm.sh/hook-delete-policy: before-hook-creation
spec:
  backoffLimit: {{ $values.backoffLimit | default 0 }}
  {{- with $values.activeDeadlineSeconds }}
  activeDeadlineSeconds: {{ . }}
  {{- end }}
  {{- with $values.ttlSecondsAfterFinished }}
  ttlSecondsAfterFinished: {{ . }}
  {{- end }}
  template:
    spec:
      restartPolicy: Never
      {{- with $root.Values.global.baserow.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $values.priorityClassName }}
      priorityClassName: {{ . }}
      {{- end }}
      {{- if $values.securityContext }}
      securityContext: {{- toYaml $values.securityContext | nindent 8 }}
      {{- else if $root.Values.global.baserow.securityContext.enabled }}
      securityContext: {{- omit $root.Values.global.baserow.securityContext "enabled" | toYaml | nindent 8 }}
      {{- end }}
      initContainers:
        # The backup and restore commands do not retry, so wait until PostgreSQL
        # accepts connections first.
        - name: wait-for-db
          image: {{ include "baserow.global.backup.image" $root }}
          imagePullPolicy: {{ $values.image.pullPolicy }}
          args: ["wait_for_db"]
          envFrom: {{- include "baserow.global.backup.envFrom" $root | nindent 12 }}
          {{- with $values.resources }}
          resources: {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if $values.containerSecurityContext }}
          securityContext: {{- toYaml $values.containerSecurityContext | nindent 12 }}
          {{- else if $root.Values.global.baserow.containerSecurityContext.enabled }}
          securityContext: {{- omit $root.Values.global.baserow.containerSecurityContext "enabled" | toYaml | nindent 12 }}
          {{- end }}
      containers:
        - name: {{ .name }}
          image: {{ include "baserow.global.backup.image" $root }}
          imagePullPolicy: {{ $values.image.pullPolicy }}
          workingDir: {{ $values.persistence.mountPath }}
          args:
            {{- toYaml .args | nindent 12 }}
          envFrom: {{- include "baserow.global.backup.envFrom" $root | nindent 12 }}
          {{- with $values.extraEnv }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $values.resources }}
          resources: {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if $values.containerSecurityContext }}
          securityContext: {{- toYaml $values.containerSecurityContext | nindent 12 }}
          {{- else if $root.Values.global.baserow.containerSecurityContext.enabled }}
          securityContext: {{- omit $root.Values.global.baserow.containerSecurityContext "enabled" | toYaml | nindent 12 }}
          {{- end }}
          volumeMounts:
            {{- if $values.persistence.existingClaim }}
            - name: backups
              mountPath: {{ $values.persistence.mountPath }}
            {{- end }}
            {{- with $values.volumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
      {{- if or $values.persistence.existingClaim $values.volumes }}
      volumes:
        {{- if $values.persistence.existingClaim }}
        - name: backups
          persistentVolumeClaim:
            claimName: {{ $values.persistence.existingClaim }}
        {{- end }}
        {{- with $values.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- end }}
      {{- with $values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
