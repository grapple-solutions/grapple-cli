package main

import (
	"context"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
	"google.golang.org/protobuf/testing/protocmp"
	"google.golang.org/protobuf/types/known/durationpb"

	"github.com/crossplane/crossplane-runtime/pkg/logging"
	fnv1beta1 "github.com/crossplane/function-sdk-go/proto/v1beta1"
	"github.com/crossplane/function-sdk-go/resource"
	"github.com/crossplane/function-sdk-go/response"

	"k8s.io/apimachinery/pkg/runtime"

	"github.com/crossplane-contrib/function-patch-and-transform/input/v1beta1"
)

func TestRunFunction(t *testing.T) {

	type args struct {
		ctx context.Context
		req *fnv1beta1.RunFunctionRequest
	}
	type want struct {
		rsp *fnv1beta1.RunFunctionResponse
		err error
	}

	cases := map[string]struct {
		reason string
		args   args
		want   want
	}{
		"ResponseIsReturned": {
			reason: "The Function should return a fatal result if no input was specified",
			args: args{
				req: &fnv1beta1.RunFunctionRequest{
					Meta: &fnv1beta1.RequestMeta{Tag: "hello"},
					Input: resource.MustStructJSON(`{
						"apiVersion": "template.fn.crossplane.io/v1beta1",
						"kind": "Input",
						"example": "Hello, world"
					}`),
				},
			},
			want: want{
				rsp: &fnv1beta1.RunFunctionResponse{
					Meta: &fnv1beta1.ResponseMeta{Tag: "hello", Ttl: durationpb.New(response.DefaultTTL)},
					Results: []*fnv1beta1.Result{
						{
							Severity: fnv1beta1.Severity_SEVERITY_NORMAL,
							Message:  "I was run with input \"Hello, world\"!",
						},
					},
				},
			},
		},
		"ObservedResourceKeepsItsName": {
			reason: "If a template corresponds to an existing observed resource we should keep its name (and namespace).",
			args: args{
				req: &fnv1beta1.RunFunctionRequest{
					Input: resource.MustStructObject(&v1beta1.Resources{
						Resources: []v1beta1.ComposedTemplate{
							{
								Name: "cool-resource",
								Base: &runtime.RawExtension{Raw: []byte(`{"apiVersion":"example.org/v1","kind":"CD"}`)},
							},
						},
					}),
					Observed: &fnv1beta1.State{
						Composite: &fnv1beta1.Resource{
							Resource: resource.MustStructJSON(`{"apiVersion":"example.org/v1","kind":"XR"}`),
						},
						Resources: map[string]*fnv1beta1.Resource{
							"cool-resource": {
								Resource: resource.MustStructJSON(`{"apiVersion":"example.org/v1","kind":"CD","metadata":{"namespace":"default","name":"cool-42"}}`),
							},
						},
					},
					Desired: &fnv1beta1.State{
						Composite: &fnv1beta1.Resource{
							Resource: resource.MustStructJSON(`{"apiVersion":"example.org/v1","kind":"XR"}`),
						},
					},
				},
			},
			want: want{
				rsp: &fnv1beta1.RunFunctionResponse{
					Meta: &fnv1beta1.ResponseMeta{Ttl: durationpb.New(response.DefaultTTL)},
					Desired: &fnv1beta1.State{
						Composite: &fnv1beta1.Resource{
							Resource: resource.MustStructJSON(`{"apiVersion":"example.org/v1","kind":"XR"}`),
						},
						Resources: map[string]*fnv1beta1.Resource{
							"cool-resource": {
								Resource: resource.MustStructJSON(`{"apiVersion":"example.org/v1","kind":"CD","metadata":{"namespace":"default","name":"cool-42"}}`),
							},
						},
					},
				},
			},
		},
	}

	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			f := &Function{log: logging.NewNopLogger()}
			rsp, err := f.RunFunction(tc.args.ctx, tc.args.req)

			if diff := cmp.Diff(tc.want.rsp, rsp, protocmp.Transform()); diff != "" {
				t.Errorf("%s\nf.RunFunction(...): -want rsp, +got rsp:\n%s", tc.reason, diff)
			}

			if diff := cmp.Diff(tc.want.err, err, cmpopts.EquateErrors()); diff != "" {
				t.Errorf("%s\nf.RunFunction(...): -want err, +got err:\n%s", tc.reason, diff)
			}
		})
	}
}
