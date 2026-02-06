package executor

import "testing"

func TestParseParallelConfig_AcceptsWorkingDirAlias(t *testing.T) {
	data := []byte(`
---TASK---
id: t1
backend: codex
working_dir: /tmp/project
---CONTENT---
Do work.
`)

	cfg, err := ParseParallelConfig(data)
	if err != nil {
		t.Fatalf("ParseParallelConfig() unexpected error: %v", err)
	}
	if len(cfg.Tasks) != 1 {
		t.Fatalf("tasks = %d, want 1", len(cfg.Tasks))
	}
	if got := cfg.Tasks[0].WorkDir; got != "/tmp/project" {
		t.Fatalf("WorkDir = %q, want %q", got, "/tmp/project")
	}
}

func TestParseParallelConfig_AcceptsReasoningEffortHyphenAlias(t *testing.T) {
	data := []byte(`
---TASK---
id: t1
backend: codex
reasoning-effort: high
workdir: /tmp/project
---CONTENT---
Do work.
`)

	cfg, err := ParseParallelConfig(data)
	if err != nil {
		t.Fatalf("ParseParallelConfig() unexpected error: %v", err)
	}
	if len(cfg.Tasks) != 1 {
		t.Fatalf("tasks = %d, want 1", len(cfg.Tasks))
	}
	if got := cfg.Tasks[0].ReasoningEffort; got != "high" {
		t.Fatalf("ReasoningEffort = %q, want %q", got, "high")
	}
}
