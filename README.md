# home-lab
Personal Setup For Provisioning My Home-Lab

kubectl -n argocd patch secret argocd-secret \
-p '{"stringData": {
"admin.password": "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0uh7CaChLa",
"admin.passwordMtime": "'$(date +%FT%T%Z)'"
}}'
