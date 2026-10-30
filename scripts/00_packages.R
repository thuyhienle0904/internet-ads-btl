# Shared R dependency manifest.
# Add a package here only after the group has agreed to use it and Phúc has been notified.
required_packages <- character()

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0L) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}
