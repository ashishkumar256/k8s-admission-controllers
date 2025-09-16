package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"github.com/spf13/cobra"
	admissionv1 "k8s.io/api/admission/v1"
	v1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

var (
	tlsCert string
	tlsKey  string
	codecs  = serializer.NewCodecFactory(runtime.NewScheme())
	logger  = log.New(os.Stdout, "http: ", log.LstdFlags)
)

var rootCmd = &cobra.Command{
	Use:   "mutate-webhook",
	Short: "Kubernetes mutate webhook example",
	Long: `Example showing how to implement a basic mutate webhook in Kubernetes.
This webhook can run on HTTPS (with certs) or HTTP (without certs).`,
	Run: func(cmd *cobra.Command, args []string) {
		if tlsCert != "" && tlsKey != "" {
			runWebhookServer(tlsCert, tlsKey, 443)
		} else {
			fmt.Println("TLS certificates not provided, running on HTTP.")
			runWebhookServer("", "", 8080)
		}
	},
}

func init() {
	rootCmd.Flags().StringVar(&tlsCert, "tls-cert", "", "Certificate for TLS")
	rootCmd.Flags().StringVar(&tlsKey, "tls-key", "", "Private key file for TLS")
}

func main() {
	cobra.CheckErr(rootCmd.Execute())
}

func admissionReviewFromRequest(r *http.Request, deserializer runtime.Decoder) (*admissionv1.AdmissionReview, error) {
	if r.Header.Get("Content-Type") != "application/json" {
		return nil, fmt.Errorf("expected application/json content-type")
	}

	var body []byte
	if r.Body != nil {
		requestData, err := ioutil.ReadAll(r.Body)
		if err != nil {
			return nil, err
		}
		body = requestData
	}

	admissionReviewRequest := &admissionv1.AdmissionReview{}
	if _, _, err := deserializer.Decode(body, nil, admissionReviewRequest); err != nil {
		return nil, err
	}

	return admissionReviewRequest, nil
}

func mutatePod(w http.ResponseWriter, r *http.Request) {
	logger.Printf("received message on mutate")

	deserializer := codecs.UniversalDeserializer()

	admissionReviewRequest, err := admissionReviewFromRequest(r, deserializer)
	if err != nil {
		msg := fmt.Sprintf("error getting admission review from request: %v", err)
		logger.Printf(msg)
		w.WriteHeader(400)
		w.Write([]byte(msg))
		return
	}

	podResource := metav1.GroupVersionResource{Group: "", Version: "v1", Resource: "pods"}
	if admissionReviewRequest.Request.Resource != podResource {
		msg := fmt.Sprintf("did not receive pod, got %s", admissionReviewRequest.Request.Resource.Resource)
		logger.Printf(msg)
		w.WriteHeader(400)
		w.Write([]byte(msg))
		return
	}

	rawRequest := admissionReviewRequest.Request.Object.Raw
	pod := corev1.Pod{}
	if _, _, err := deserializer.Decode(rawRequest, nil, &pod); err != nil {
		msg := fmt.Sprintf("error decoding raw pod: %v", err)
		logger.Printf(msg)
		w.WriteHeader(500)
		w.Write([]byte(msg))
		return
	}

	admissionResponse := &admissionv1.AdmissionResponse{}
	var patch string
	patchType := v1.PatchTypeJSONPatch

	namespace := admissionReviewRequest.Request.Namespace
	kubeconfig, err := rest.InClusterConfig()
	if err != nil {
		msg := fmt.Sprintf("error loading in-cluster config: %v", err)
		logger.Printf(msg)
		w.WriteHeader(500)
		w.Write([]byte(msg))
		return
	}
	clientset, err := kubernetes.NewForConfig(kubeconfig)
	if err != nil {
		msg := fmt.Sprintf("error creating clientset: %v", err)
		logger.Printf(msg)
		w.WriteHeader(500)
		w.Write([]byte(msg))
		return
	}
	ns, err := clientset.CoreV1().Namespaces().Get(context.TODO(), namespace, metav1.GetOptions{})
	if err != nil {
		msg := fmt.Sprintf("error getting namespace: %v", err)
		logger.Printf(msg)
		w.WriteHeader(500)
		w.Write([]byte(msg))
		return
	}

	if ns.Labels["sidecar"] == "enabled" {
		sidecar := corev1.Container{
			Name:  "sidecar-container",
			Image: "busybox:latest",
			Args:  []string{"sleep", "3600"},
		}
		sidecarJSON, _ := json.Marshal(sidecar)
		patch = fmt.Sprintf(`[{"op":"add","path":"/spec/containers/-","value":%s}]`, string(sidecarJSON))
	}

	admissionResponse.Allowed = true
	if patch != "" {
		admissionResponse.PatchType = &patchType
		admissionResponse.Patch = []byte(patch)
	}

	var admissionReviewResponse admissionv1.AdmissionReview
	admissionReviewResponse.Response = admissionResponse
	admissionReviewResponse.SetGroupVersionKind(admissionReviewRequest.GroupVersionKind())
	admissionReviewResponse.Response.UID = admissionReviewRequest.Request.UID

	resp, err := json.Marshal(admissionReviewResponse)
	if err != nil {
		msg := fmt.Sprintf("error marshalling response json: %v", err)
		logger.Printf(msg)
		w.WriteHeader(500)
		w.Write([]byte(msg))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(resp)
}

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

func runWebhookServer(certFile, keyFile string, port int) {
	// A new, temporary tls.Config is created to satisfy the compiler's unused import check.
	_ = &tls.Config{}
	
	http.HandleFunc("/mutate", mutatePod)
	http.HandleFunc("/healthz", healthzHandler)
	server := http.Server{
		Addr:     fmt.Sprintf(":%d", port),
		ErrorLog: logger,
	}

	if certFile != "" && keyFile != "" {
		fmt.Printf("Starting webhook server on HTTPS at port %d\n", port)
		if err := server.ListenAndServeTLS(certFile, keyFile); err != nil {
			panic(err)
		}
	} else {
		fmt.Printf("Starting webhook server on HTTP at port %d\n", port)
		if err := server.ListenAndServe(); err != nil {
			panic(err)
		}
	}
}
