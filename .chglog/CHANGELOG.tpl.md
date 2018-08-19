{{ if .Info.Title -}}
{{ if .Info.RepositoryURL -}}
# [{{.Info.Title}}][repo]
[repo]: {{ .Info.RepositoryURL }}
{{ else -}}
# {{.Info.Title}}
{{ end -}}
{{ end -}}

{{ if .Versions -}}
{{ if .Unreleased.CommitGroups -}}
## [Unreleased]
{{ range .Unreleased.CommitGroups -}}
{{ range .Commits -}}
- {{ .Header -}}
{{ end }}
{{ end -}}
{{ end -}}
{{ end -}}

{{ range .Versions }}
{{ if .Tag.Previous -}}
## [{{ .Tag.Name }}][diff-{{ .Tag.Name }}] - {{ datetime "2006-01-02" .Tag.Date }}
{{ else -}}
## {{ .Tag.Name }} - {{ datetime "2006-01-02" .Tag.Date }}
{{ end -}}

{{ range .CommitGroups -}}
{{ range .Commits -}}
- {{ .Header -}}
{{ end }}
{{ end -}}

{{- if .NoteGroups -}}
{{ range .NoteGroups -}}
### {{ .Title }}
{{ range .Notes }}
{{ .Body }}
{{ end }}
{{ end -}}
{{ end -}}
{{ end -}}

{{- if .Versions }}
{{ if .Unreleased.CommitGroups -}}
[Unreleased]: {{ .Info.RepositoryURL }}/compare/{{ $latest := index .Versions 0 }}{{ $latest.Tag.Name }}...HEAD
{{ end -}}
{{ range .Versions -}}
{{ if .Tag.Previous -}}
[diff-{{ .Tag.Name }}]: {{ $.Info.RepositoryURL }}/compare/{{ .Tag.Previous.Name }}...{{ .Tag.Name }}
{{ end -}}
{{ end -}}
{{ end -}}
