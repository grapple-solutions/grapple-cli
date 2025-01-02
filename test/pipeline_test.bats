
@test "kubectl installed" {
    run kubectl version --client
    [ "$status" -eq 0 ]
}

@test "civo installed" {
    run civo version
    [ "$status" -eq 0 ]
}

@test "show logs command works" {
    run ../grpl
    [ "$status" -eq 0 ]
}
