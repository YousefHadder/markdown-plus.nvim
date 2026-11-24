# Security Policy

## Supported Versions

The project does not currently publish a support window for specific releases. The latest release listed on the [GitHub Releases page](https://github.com/YousefHadder/markdown-plus.nvim/releases) is recommended; please report vulnerabilities affecting any release.

## Reporting a Vulnerability

Please report suspected vulnerabilities through [GitHub's private vulnerability reporting](https://github.com/YousefHadder/markdown-plus.nvim/security/advisories/new). Do not report security issues in public issues or discussions. Include the affected release or commit, impact, and reproduction details where possible; do not include credentials or other secrets.

There is no published response-time commitment. We will coordinate follow-up and disclosure through the private advisory.

## Dependency Scanning

Pull requests run GitHub's dependency review against dependency changes recognized by the GitHub dependency graph, including supported GitHub Actions dependencies. Dependabot checks GitHub Actions dependencies weekly. LuaRocks rockspecs are not a supported dependency-graph ecosystem, so these checks do not provide vulnerability coverage for dependencies declared only in rockspecs.

GitHub does not generate Dependabot alerts for GitHub Actions dependencies pinned only to commit SHAs. Review and update those references separately; dependency alerts do not provide complete coverage for them.
