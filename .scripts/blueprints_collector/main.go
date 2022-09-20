package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
)

var marketplacePath = flag.String("p", "./", "path to marketplace directory")

func main() {
	flag.Parse()

	changed, err := changedBlueprints(*marketplacePath, os.Args[1:])
	if err != nil {
		fmt.Printf("::error::failed to get chnaged blueprints: %s\n", err)
		os.Exit(1)
	}

	paths := make([]string, 0, len(changed))
	for path := range changed {
		paths = append(paths, path)
	}

	fmt.Printf("::set-output name=blueprints-paths::%s", strings.Join(paths, " "))
}

func changedBlueprints(marketplacePath string, changedFiles []string) (map[string]struct{}, error) {
	bpCats, err := blueprintCategories(marketplacePath)
	if err != nil {
		return nil, fmt.Errorf("get current blueprints categories: %w", err)
	}

	changedBps := make(map[string]struct{})
	for _, path := range changedFiles {
		for _, cat := range bpCats {
			if strings.HasPrefix(path, cat) {
				changedBps[strings.Join(strings.Split(path, "/")[:2], "/")] = struct{}{}
			}
		}
	}

	return changedBps, nil
}

func blueprintCategories(marketplacePath string) ([]string, error) {
	entries, err := os.ReadDir(marketplacePath)
	if err != nil {
		return nil, fmt.Errorf("open marketplace directory: %w", err)
	}

	cats := make([]string, 0, len(entries))
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		if strings.HasPrefix(entry.Name(), ".") {
			continue
		}

		cats = append(cats, entry.Name())
	}

	return cats, nil
}
