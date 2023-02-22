package main

import (
  "errors"
  "flag"
  "fmt"
  "os"
  "path/filepath"

  "gopkg.in/yaml.v3"
)

var errLinterFailed = errors.New("linter failed")

type vendorID = string

type Vendor struct {
  ID string `yaml:"id"`
}

type Blueprint struct {
  VendorID yaml.Node `yaml:"vendor"`
}

func main() {
  vendorsFilePath := flag.String("vp", "./.vendors/vendors.yml", "path to vendors file")
  flag.Parse()
  if err := run(*vendorsFilePath, flag.Args()); err != nil {
    if !errors.Is(err, errLinterFailed) {
      fmt.Printf("::error:: failed run blueprint vendor validation %s\n", err)
    }
    os.Exit(1)
  }
}

func run(vendorsFilePath string, bpsPaths []string) error {
  vendorsIDs, err := parseVendorsIDs(vendorsFilePath)
  if err != nil {
    return fmt.Errorf("parse vendors: %w", err)
  }

  err = validateBlueprints(vendorsIDs, bpsPaths)
  if err != nil {
    return fmt.Errorf("validate blueprints: %w", err)
  }

  return nil
}

func parseVendorsIDs(vendorsFilePath string) (map[vendorID]struct{}, error) {
  f, err := os.Open(vendorsFilePath)
  if err != nil {
    return nil, fmt.Errorf("open file: %w", err)
  }
  defer f.Close()

  var vendors []Vendor
  err = yaml.NewDecoder(f).Decode(&vendors)
  if err != nil {
    return nil, fmt.Errorf("parse yaml: %w", err)
  }

  vendorsMap := make(map[vendorID]struct{}, len(vendors))

  for _, v := range vendors {
    vendorsMap[v.ID] = struct{}{}
  }

  return vendorsMap, nil
}

func validateBlueprints(vendorIDs map[vendorID]struct{}, bpsPaths []string) error {
  resOk := true

  for _, bpPath := range bpsPaths {
    filePath := filepath.Join(bpPath, "manifest.yml")
    bp, err := parseBlueprint(filePath)
    if err != nil {
      return fmt.Errorf("parse blueprint %q: %w", bpPath, err)
    }

    if bp.VendorID.Value == "" {
      continue
    }

    if _, ok := vendorIDs[bp.VendorID.Value]; !ok {
      resOk = false
      logVendorNotFound(filePath, bp.VendorID)
    }
  }

  if !resOk {
    return errLinterFailed
  }

  return nil
}

func parseBlueprint(path string) (Blueprint, error) {
  f, err := os.Open(path)
  if err != nil {
    return Blueprint{}, fmt.Errorf("open file: %w", err)
  }
  defer f.Close()

  var manifest Blueprint
  err = yaml.NewDecoder(f).Decode(&manifest)
  if err != nil {
    return Blueprint{}, fmt.Errorf("parse yaml: %w", err)
  }

  return manifest, nil
}

func logVendorNotFound(filePath string, v yaml.Node) {
  fmt.Printf(
    "::warning file=%s,line=%d,col=%d::vendor %s not found at "+
      "https://github.com/Enapter/marketplace/blob/main/.vendors/vendors.yml\n",
    filePath, v.Line, v.Column, v.Value,
  )
}
