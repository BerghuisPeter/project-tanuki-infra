project_id                = "tanuki-dev"
region                    = "asia-northeast1"
environment               = "dev"
gar_location              = "asia-northeast1"
cloud_run_service_account = "tanuki-cloudrun-runtime@tanuki-dev.iam.gserviceaccount.com"

#CORS
app_cors_allowed_origins = "https://www.dev.project-tanuki.net;https://dev.project-tanuki.net"

# back
gar_repository         = "tanuki-back-repo"
db_username            = "tanuki-user"
jwt_expiration         = "3600000"
jwt_refresh_expiration = "86400000"

google_client_id    = "583627204016-5o809inoo1hs877478cqtthd15h0a3hn.apps.googleusercontent.com"
google_redirect_uri = "https://dev.project-tanuki.net/"

# front
angular_gar_repo   = "tanuki-angular-repo"
angular_image_name = "tanuki-angular"

socket_gar_repo   = "tanuki-socket-repo"
socket_image_name = "tanuki-socket"

front_url = "https://dev.project-tanuki.net"