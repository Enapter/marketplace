package main

import (
  "errors"
  "flag"
  "fmt"
  "os"
  "path/filepath"
  "strings"

  "gopkg.in/yaml.v3"
)

const devicesFile = ".marketplace/devices/devices.yml"

var errLinterFailed = errors.New("linter failed")

type Device struct {
  ID               string `yaml:"id"`
  BlueprintOptions []struct {
    Blueprint string `yaml:"blueprint"`
  } `yaml:"blueprint_options"`
}

func main() {
  marketplacePath := flag.String("p", "./", "path to marketplace directory")
  flag.Parse()

  if err := run(*marketplacePath); err != nil {
    if !errors.Is(err, errLinterFailed) {
      fmt.Printf("::error:: failed run device-blueprint link validation %s\n", err)
    }
    os.Exit(1)
  }
}

func run(marketplacePath string) error {
  devices, err := parseDevices(filepath.Join(marketplacePath, devicesFile))
  if err != nil {
    return fmt.Errorf("parse devices")
  }

  repoEntries, err := os.ReadDir(marketplacePath)
  if err != nil {
    return fmt.Errorf("read repo dir: %w", err)
  }

  blueprintsPaths := make(map[string]struct{})

  for _, entry := range repoEntries {
    if !entry.IsDir() {
      continue
    }

    if strings.HasPrefix(entry.Name(), ".") {
      continue
    }

    categoryPath := filepath.Join(marketplacePath, entry.Name())

    categoryEntities, err := os.ReadDir(categoryPath)
    if err != nil {
      return fmt.Errorf("read dir %s: %w", categoryPath, err)
    }

    for _, entity := range categoryEntities {
      if !entity.IsDir() {
        continue
      }
      blueprintsPaths[filepath.Join(entry.Name(), entity.Name())] = struct{}{}
    }
  }

  for _, d := range devices {
    for _, o := range d.BlueprintOptions {
      delete(blueprintsPaths, o.Blueprint)
    }
  }

  for path := range blueprintsPaths {
    fmt.Printf("::warning file=%s::%s\n", path, "blueprint should be pinned to device")
  }

  if len(blueprintsPaths) > 0 {
    return errLinterFailed
  }

  return nil
}

func parseDevices(filePath string) ([]Device, error) {
  f, err := os.Open(filePath)
  if err != nil {
    return nil, fmt.Errorf("open file: %w", err)
  }
  defer f.Close()

  var devices []Device
  err = yaml.NewDecoder(f).Decode(&devices)
  if err != nil {
    return nil, fmt.Errorf("parse yaml: %w", err)
  }

  return devices, nil
}
