# Rendered by scripts/lib/platform.sh (apply_inference_ingress).
# @INGRESS_SCHEME@ and @INBOUND_CIDRS@ are substituted at apply time so the
# public listener is never created without an explicit source range.
# Do not apply this file directly with kubectl.
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vllm-openai-ingress
  namespace: app
  annotations:
    alb.ingress.kubernetes.io/group.name: public-edge
    alb.ingress.kubernetes.io/group.order: "10"
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/inbound-cidrs: "@INBOUND_CIDRS@"
    alb.ingress.kubernetes.io/scheme: @INGRESS_SCHEME@
    alb.ingress.kubernetes.io/success-codes: "200"
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /v1
            pathType: Prefix
            backend:
              service:
                name: vllm-openai
                port:
                  number: 80
