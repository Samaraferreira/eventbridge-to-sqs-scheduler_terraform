resource "aws_sqs_queue" "main-queue-fifo" {
  name                        = join("-", [var.environment, "main", "queue.fifo"])
  fifo_queue                  = true
  content_based_deduplication = true
  delay_seconds               = 0
  max_message_size            = 51200  # 50 kb
  message_retention_seconds   = 345600 # 4 days
  receive_wait_time_seconds   = 10
  visibility_timeout_seconds  = 180
}

resource "aws_sqs_queue_policy" "main-queue-fifo-policy" {
  queue_url = aws_sqs_queue.main-queue-fifo.id
  policy    = data.aws_iam_policy_document.main-queue-policy-doc.json
}

data "aws_iam_policy_document" "main-queue-policy-doc" {
  statement {
    effect  = "Allow"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sqs_queue.main-queue-fifo.arn]
  }
}

resource "aws_cloudwatch_event_rule" "sqs-reminder" {
  name                = join("-", [var.environment, "sqs-reminder-rule"])
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "sqs-reminder" {
  arn  = aws_sqs_queue.main-queue-fifo.arn
  rule = aws_cloudwatch_event_rule.sqs-reminder.name
  sqs_target {
    message_group_id = "main"
  }

  input_transformer {
    input_paths = {
      time = "$.time"
    }

    input_template = <<INPUT_TEMPLATE_EOF
    {
      "time":<time>,
      "name": "test"
    }
    INPUT_TEMPLATE_EOF
  }

  # input = jsonencode({ "event" : "reminder" })
}
