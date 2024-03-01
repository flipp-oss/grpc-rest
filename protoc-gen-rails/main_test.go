package main

import (
    "fmt"
    "github.com/stretchr/testify/assert"
    "os"
  "os/exec"
    "path/filepath"
    "strings"
  "testing"
)

// Overall approach taken from https://github.com/mix-php/mix/blob/master/src/grpc/protoc-gen-mix/plugin_test.go

// When the environment variable RUN_AS_PROTOC_GEN_RAILS is set, we skip running
// tests and instead act as protoc-gen-rails. This allows the test binary to
// pass itself to protoc.
func init() {
    if os.Getenv("RUN_AS_PROTOC_GEN_RAILS") != "" {
        main()
        os.Exit(0)
    }
}

func fileNames(directory string, appendDirectory bool, extension string) ([]string, error) {
    var files []os.FileInfo
    var fullPaths []string
    err := filepath.Walk(directory, func(path string, info os.FileInfo, err error) error {
        if extension != "" && filepath.Ext(path) != extension {
            return nil
        }
        if info.IsDir() {
            return nil
        }
        files = append(files, info)
        fullPaths = append(fullPaths, path)
        if err != nil {
            fmt.Println("ERROR:", err)
        }
        return nil
    })
    if err != nil {
        return nil, fmt.Errorf("can't read %s directory: %w", directory, err)
    }
    if appendDirectory {
        return fullPaths, nil
    }
    var names []string
    for _, file := range fullPaths {
      names = append(names, strings.Replace(file, directory, "", 1)[1:])
    }
    return names, nil
}

func runTest(t *testing.T, directory string, options map[string]string) {
    workdir, _ := os.Getwd()
    tmpdir, err := os.MkdirTemp(workdir, "proto-test.")
    if err != nil {
        t.Fatal(err)
    }
    defer os.RemoveAll(tmpdir)

    args := []string{
        "-I.",
        "--rails_out=" + tmpdir,
    }
    names, err := fileNames(workdir + "/testdata", false, ".proto")
    if err != nil {
        t.Fatal(fmt.Errorf("testData fileNames %w", err))
    }
    for _, name := range names {
        args = append(args, fmt.Sprintf("testdata/%v", name))
    }
    for k, v := range options {
        args = append(args, "--rails_opt=" + k + "=" + v)
    }
    protoc(t, args)

    testDir := workdir + "/testdata/" + directory
    if os.Getenv("UPDATE_SNAPSHOTS") != "" {
        cmd := exec.Command("/bin/sh", "-c", fmt.Sprintf("cp %v/* %v", tmpdir, testDir))
        cmd.Run()
    } else {
        assertEqualFiles(t, testDir, tmpdir)
    }
}

func Test_Base(t *testing.T) {
    runTest(t, "base", map[string]string{})
}

func assertEqualFiles(t *testing.T, original, generated string) {
    names, err := fileNames(original, false, "")
    if err != nil {
        t.Fatal(fmt.Errorf("original fileNames %w", err))
    }
    generatedNames, err := fileNames(generated, false, "")
    if err != nil {
        t.Fatal(fmt.Errorf("generated fileNames %w", err))
    }
    assert.Equal(t, names, generatedNames)
    // put back subdirectories
    names, _ = fileNames(original, true, "")
    generatedNames, _ = fileNames(generated, true, "")
    for i, name := range names {
        originalData, err := os.ReadFile(name)
        if err != nil {
            t.Fatal("Can't find original file for comparison")
        }

        generatedData, err := os.ReadFile(generatedNames[i])
        if err != nil {
            t.Fatal("Can't find generated file for comparison")
        }
        r := strings.NewReplacer("\r\n", "", "\n", "")
        assert.Equal(t, r.Replace(string(originalData)), r.Replace(string(generatedData)))
    }
}

func protoc(t *testing.T, args []string) {
    cmd := exec.Command("protoc", "--proto_path=.", "--proto_path=./google-deps", "--plugin=protoc-gen-rails=" + os.Args[0])
    cmd.Args = append(cmd.Args, args...)
    cmd.Env = append(os.Environ(), "RUN_AS_PROTOC_GEN_RAILS=1")
    out, err := cmd.CombinedOutput()

    if len(out) > 0 || err != nil {
        t.Log("RUNNING: ", strings.Join(cmd.Args, " "))
    }

    if len(out) > 0 {
        t.Log(string(out))
    }

    if err != nil {
        t.Fatalf("protoc: %v", err)
    }
}
