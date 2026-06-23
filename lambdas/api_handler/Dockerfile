FROM public.ecr.aws/lambda/python:3.12

COPY handler.py ${LAMBDA_TASK_ROOT}/handler.py

RUN pip install boto3 --upgrade

CMD ["handler.lambda_handler"]