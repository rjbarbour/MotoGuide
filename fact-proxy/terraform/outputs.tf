output "app_name" {
  description = "Managed Fly app name."
  value       = fly_app.fact_proxy.name
}

output "app_url" {
  description = "Managed Fly app URL."
  value       = fly_app.fact_proxy.appurl
}
