package main

import (
  "errors"
  "flag"
  "fmt"
  "net/http"
  "os"
  "path/filepath"
  "strings"

  "gopkg.in/yaml.v3"
)

const (
  devicesFile = ".marketplace/devices/devices.yml"
  vendorsFile = ".marketplace/vendors/vendors.yml"
)

var errLinterFailed = errors.New("linter failed")

type VerificationLevel = string

const (
  VerificationLevelReadyForTesting VerificationLevel = "ready_for_testing"
  VerificationLevelCommunityTested VerificationLevel = "community_tested"
  VerificationLevelVerified        VerificationLevel = "verified"
)

type vendorID = string

type Vendor struct {
  ID string `yaml:"id"`
}

type Device struct {
  ID               yaml.Node `yaml:"id"`
  DisplayName      yaml.Node `yaml:"display_name"`
  Description      yaml.Node `yaml:"description"`
  IconID           yaml.Node `yaml:"icon"`
  VendorID         yaml.Node `yaml:"vendor,omitempty"`
  CategoryID       yaml.Node `yaml:"category"`
  BlueprintOptions yaml.Node `yaml:"blueprint_options"`
}

type BlueprintOption struct {
  Blueprint         yaml.Node `yaml:"blueprint"`
  DisplayName       yaml.Node `yaml:"display_name"`
  Description       yaml.Node `yaml:"description"`
  VerificationLevel yaml.Node `yaml:"verification_level"`
}

func main() {
  marketplacePath := flag.String("p", "./", "path to marketplace directory")
  flag.Parse()

  if err := run(*marketplacePath, flag.Args()); err != nil {
    if !errors.Is(err, errLinterFailed) {
      fmt.Printf("::error:: failed run marketplace devcies validation %s\n", err)
    }
    os.Exit(1)
  }
}

func run(marketplacePath string, changedFilesPaths []string) error {
  if !devicesFileChanged(changedFilesPaths) {
    return nil
  }

  vendorIDs, err := parseVendorIDs(filepath.Join(marketplacePath, vendorsFile))
  if err != nil {
    return fmt.Errorf("parse vendors: %w", err)
  }

  devices, err := parseDevices(filepath.Join(marketplacePath, devicesFile))
  if err != nil {
    return fmt.Errorf("parse devices: %w", err)
  }

  err = validateDevices(devices, vendorIDs)
  if err != nil {
    return fmt.Errorf("validate devices: %w", err)
  }

  return nil
}

func devicesFileChanged(changedFiles []string) bool {
  for _, file := range changedFiles {
    if file == devicesFile {
      return true
    }
  }
  return false
}

func parseVendorIDs(filePath string) (map[vendorID]struct{}, error) {
  f, err := os.Open(filePath)
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

func validateDevices(devices []Device, vendorIDs map[vendorID]struct{}) error {
  resOk := true
  devicesIDs := make(map[string]struct{}, len(devices))

  for _, d := range devices {
    if !checkRequiredAndNotEmpty("id", d.ID) {
      resOk = false
    }

    if _, found := devicesIDs[d.ID.Value]; found {
      logDeviceWarning(d.ID.Line, d.ID.Column, "not unique device id")
      resOk = false
      continue
    }

    devicesIDs[d.ID.Value] = struct{}{}

    if !checkRequiredAndNotEmpty(d.ID.Value+".display_name", d.DisplayName) {
      resOk = false
    }

    if !checkRequiredAndNotEmpty(d.ID.Value+".description", d.Description) {
      resOk = false
    }

    ok, err := validateDeviceIcon(d.ID.Value+".icon", d.IconID)
    if err != nil {
      return fmt.Errorf("validate device icon: %w", err)
    }

    if !ok {
      resOk = false
    }

    ok, err = validateCategory(d.ID.Value+".category", d.CategoryID)
    if err != nil {
      return fmt.Errorf("validate device category: %w", err)
    }

    if !ok {
      resOk = false
    }

    if !validateVendor(d.VendorID, vendorIDs) {
      resOk = false
    }

    ok, err = validateBlueprintOptions(d.ID.Value+".blueprint_options", d.BlueprintOptions)
    if err != nil {
      return fmt.Errorf("validate device blueprint options: %w", err)
    }

    if !ok {
      resOk = false
    }
  }

  if !resOk {
    return errLinterFailed
  }

  return nil
}

func validateDeviceIcon(name string, node yaml.Node) (bool, error) {
  if !checkRequiredAndNotEmpty(name, node) {
    return false, nil
  }

  iconURL := fmt.Sprintf("https://static.enapter.com/material-community/%s.svg", node.Value)

  if strings.HasPrefix(node.Value, "enapter") {
    iconURL = fmt.Sprintf("https://static.enapter.com/enapter-icons/%s.svg", node.Value)
  }

  ok, err := checkResourceExistsAtURL(iconURL)
  if err != nil {
    return false, fmt.Errorf("check blueprint icon: %w", err)
  }

  if !ok {
    logDeviceWarning(
      node.Line, node.Column,
      "icon should be only from enapter icons or material community asset",
    )
    return false, nil
  }

  return true, nil
}

func validateVendor(node yaml.Node, ids map[vendorID]struct{}) bool {
  if node.Value == "" {
    return true
  }

  if _, ok := ids[node.Value]; !ok {
    logDeviceWarning(
      node.Line, node.Column,
      fmt.Sprintf("%s vendor id not found at %s", node.Value, vendorsFile),
    )
    return false
  }

  return true
}

func validateCategory(name string, node yaml.Node) (bool, error) {
  if !checkRequiredAndNotEmpty(name, node) {
    return false, nil
  }

  _, err := os.ReadDir(node.Value)
  if err != nil {
    if os.IsNotExist(err) {
      logDeviceWarning(node.Line, node.Column, fmt.Sprintf("%s category is not exist", node.Value))
      return false, nil
    }
    return false, err
  }

  return true, nil
}

func validateBlueprintOptions(name string, node yaml.Node) (bool, error) {
  if !checkRequiredValue(name, node) {
    return false, nil
  }

  var opts []BlueprintOption
  err := node.Decode(&opts)
  if err != nil {
    return false, fmt.Errorf("decode: %w", err)
  }

  if len(opts) == 0 {
    logDeviceWarning(node.Line, node.Column, "blueprint options should not be zero")
    return false, nil
  }

  for _, opt := range opts {
    if !checkRequiredAndNotEmpty(name+".blueprint", opt.Blueprint) {
      return false, nil
    }

    _, err := os.Open(filepath.Join(opt.Blueprint.Value, "manifest.yml"))
    if err != nil {
      if os.IsNotExist(err) {
        logDeviceWarning(
          opt.Blueprint.Line, opt.Blueprint.Column,
          fmt.Sprintf("%s probably is not a blueprint", opt.Blueprint.Value),
        )
        return false, nil
      }
      return false, err
    }

    if !checkRequiredAndNotEmpty(name+".verification_level", opt.VerificationLevel) {
      return false, err
    }

    switch opt.VerificationLevel.Value {
    case VerificationLevelVerified,
      VerificationLevelReadyForTesting,
      VerificationLevelCommunityTested:
    default:
      logDeviceWarning(
        opt.VerificationLevel.Line,
        opt.VerificationLevel.Column,
        "invalid value verification_level should be only verified, community_tested or ready_for_testing",
      )
      return false, nil
    }

    if len(opts) > 1 {
      if !checkRequiredAndNotEmpty(name+".display_name", opt.DisplayName) {
        return false, nil
      }

      if !checkRequiredAndNotEmpty(name+".description", opt.Description) {
        return false, nil
      }
    }
  }

  return true, nil
}

func checkRequiredAndNotEmpty(name string, node yaml.Node) bool {
  if !checkRequiredValue(name, node) {
    return false
  }

  if node.Value == "" {
    logDeviceWarning(node.Line, node.Column, fmt.Sprintf("%s should not be empty", name))
    return false
  }

  return true
}

func checkRequiredValue(name string, node yaml.Node) bool {
  if node.IsZero() {
    logDeviceWarning(node.Line, node.Column, fmt.Sprintf("%s is a required field", name))
    return false
  }
  return true
}

func checkResourceExistsAtURL(url string) (bool, error) {
  r, err := http.Get(url)
  if err != nil {
    return false, fmt.Errorf("check url: %w", err)
  }
  defer r.Body.Close()

  return r.StatusCode == http.StatusOK, nil
}

func logDeviceWarning(line, column int, msg string) {
  fmt.Printf("::warning file=%s,line=%d,col=%d::%s\n", devicesFile, line, column, msg)
}
