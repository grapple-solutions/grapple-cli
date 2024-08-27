package main

import (
	"context"
	"fmt"
	"log"
	"regexp"
	"strings"

	"github.com/crossplane/crossplane-runtime/pkg/errors"
	"github.com/crossplane/crossplane-runtime/pkg/logging"
	"github.com/crossplane/function-example/input/v1beta1"
	fnv1beta1 "github.com/crossplane/function-sdk-go/proto/v1beta1"
	"github.com/crossplane/function-sdk-go/request"
	"github.com/crossplane/function-sdk-go/response"

	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

// Function returns whatever response you ask it to.
type Function struct {
	fnv1beta1.UnimplementedFunctionRunnerServiceServer

	log logging.Logger
}

// RunFunction runs the Function.
func (f *Function) RunFunction(_ context.Context, req *fnv1beta1.RunFunctionRequest) (*fnv1beta1.RunFunctionResponse, error) {
	f.log.Info("Running function", "tag", req.GetMeta().GetTag())

	rsp := response.To(req, response.DefaultTTL)

	in := &v1beta1.Input{}
	if err := request.GetInput(req, in); err != nil {
		response.Fatal(rsp, errors.Wrapf(err, "cannot get Function input from %T", req))
		return rsp, nil
	}

	// Set up the Kubernetes client
	config, err := clientcmd.BuildConfigFromFlags("", clientcmd.RecommendedHomeFile)
	if err != nil {
		response.Fatal(rsp, errors.Wrapf(err, "Failed to build kubeconfig"))
		return rsp, nil
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		response.Fatal(rsp, errors.Wrapf(err, "Failed to create Kubernetes client"))
		return rsp, nil
	}

	// Namespace and secret name
	namespace := "grpl-system"
	secretName := "grsf-config"
	newLicenseValue := "free"
	var secret *v1.Secret
	// Read the secret
	secret, err = clientset.CoreV1().Secrets(namespace).Get(context.TODO(), secretName, metav1.GetOptions{})
	if err != nil {
		response.Fatal(rsp, errors.Wrapf(err, "Failed to get secret"))
		return rsp, nil
	}

	if isValidEmailAddress(in.Email) {

		// getting LIC value
		lic := string(secret.Data["LIC"])

		fmt.Printf("Current LIC value: %s\n", string(lic))

		// getting new licience value
		newLicenseValue = determineLicenseValue(string(lic))

	}

	// saving the value
	secret.Data["GRAPPLE_LICENSE"] = []byte(newLicenseValue)

	// Update the secret
	_, err = clientset.CoreV1().Secrets(namespace).Update(context.TODO(), secret, metav1.UpdateOptions{})
	if err != nil {
		log.Fatalf("Failed to update secret: %v", err)
	}

	fmt.Printf("Updated GRAPPLE_LICENSE to: %s\n", newLicenseValue)

	return rsp, nil
}

func isValidEmailAddress(email string) bool {
	var emailRegex = regexp.MustCompile(`^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,4}$`)
	return emailRegex.MatchString(strings.ToLower(email))
}

func determineLicenseValue(lic string) string {
	switch lic {
	case "starter":
		return "starter"
	case "pro":
		return "pro"
	case "enterprise":
		return "enterprise"
	default:
		return "free"
	}
}
