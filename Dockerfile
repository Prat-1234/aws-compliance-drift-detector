FROM public.ecr.aws/lambda/python:3.12

# Copy compliance checker (default — overridden per function in CI/CD)
COPY lambdas/compliance_checker/handler.py ${LAMBDA_TASK_ROOT}/handler.py

RUN pip install boto3 --upgrade

CMD ["handler.lambda_handler"]