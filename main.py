import argparse
import logging
import logging.handlers
import os
import threading
from enum import StrEnum

import openai
from openai import OpenAI
from pydantic import BaseModel

### Utils


def load_prompt(path: str) -> str:
    with open(path, 'r') as fp:
        prompt = fp.read()
    return prompt


def get_logger(
    name: str,
    filename: str,
    format: str,
    level: int = logging.DEBUG,
) -> logging.Logger:
    """Create logger."""
    logger = logging.getLogger(name)

    if len(logger.handlers) > 0:
        return logger

    logger.setLevel(level=level)

    formatter = logging.Formatter(format, style='{')

    stream_handler = logging.StreamHandler()
    stream_handler.setLevel(level=level)
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)

    file_handler = logging.handlers.RotatingFileHandler(filename)
    file_handler.setLevel(level=logging.INFO)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    return logger


class InferenceEngine(StrEnum):
    ollama = 'ollama'


class Model(StrEnum):
    # Add models here.
    qwen3_32b = 'qwen3:32b-fp16'
    qwen3_14b = 'qwen3:14b-fp16'
    qwen3_a3b = 'qwen3:30b-a3b-fp16'
    qwen3_a3b_2507 = 'qwen3:30b-a3b-instruct-2507-fp16'
    gpt_oss_20b = 'gpt-oss:20b'
    gpt_oss_120b = 'gpt-oss:120b'

    # ("-cm" is a custom model with max context size.)
    qwen3_32b_cm = 'qwen3:32b-fp16-cm'
    qwen3_14b_cm = 'qwen3:14b-fp16-cm'
    qwen3_a3b_cm = 'qwen3:30b-a3b-fp16-cm'
    qwen3_a3b_2507_cm = 'qwen3:30b-a3b-instruct-2507-fp16-cm'
    gpt_oss_20b_cm = 'gpt-oss:20b-cm'
    gpt_oss_120b_cm = 'gpt-oss:120b-cm'


def get_client(
    engine: InferenceEngine,
    is_multi_port: bool,
    index: int,
):
    engine = engine.value
    url_env_key = f'{engine.upper()}_ENDPOINT'
    endpoint = os.getenv(url_env_key)
    assert endpoint, f'Endpoint not valid. Set env "{url_env_key}".'

    port_env_key = f'{engine.upper()}_PORT'
    port = os.getenv(port_env_key)
    assert port, f'Port not valid. Set env "{port_env_key}".'
    port = int(port)

    port = f'{port + index}' if is_multi_port else f'{port}'
    endpoint = endpoint.format(port=port)

    client = OpenAI(
        base_url=endpoint,
        api_key=engine,  # This can be anything.
    )

    return client


### LLM calling


def call_llm_stream(
    client: OpenAI,
    model: str,
    prompt: str,
    system_prompt: str,
    logger: logging.Logger,
    temperature: float = 1.0,
    top_p: float = 0.95,
    enable_thinking: bool = False,
):
    with client.chat.completions.stream(
        model=model,
        messages=[
            {'role': 'system', 'content': system_prompt},
            {
                'role': 'user',
                'content': prompt + ' /no_think' if not enable_thinking and model.startswith('qwen3') else '',
            },
        ],
        temperature=temperature,
        top_p=top_p,
    ) as stream:
        for event in stream:
            if event.type == 'error':
                logger.error(f'error: {event.error}')
            elif event.type == 'content.delta':
                logger.info(event.delta)

    response = stream.get_final_completion()
    output = response.choices[0].message.content

    return output


class Config(BaseModel):
    engine: InferenceEngine
    model: Model
    multiport: bool

    system_prompt: str
    user_prompt: str
    temperature: float = 1.0
    top_p: float = 0.95

    log_folder: str


def job(
    id: int,
    config: Config,
):
    process_name = f'P{id:02d}'

    logger = get_logger(
        process_name,
        filename=os.path.join(config.log_folder, f'{process_name}.log'),
        format='{asctime} | {levelname:8.8s} | - ' + f'[{process_name}]' + ' {message}',
    )
    logger.info('Created logger')

    logger.info(f'Process ID: {id}')
    logger.info(f'Config:\n{config.model_dump_json(indent=2)}')

    client = get_client(engine=config.engine, index=id, is_multi_port=config.multiport)
    logger.info('Created client')

    try:
        output = call_llm_stream(
            client=client,
            model=config.model.value,
            prompt=config.user_prompt,
            system_prompt=config.system_prompt,
            logger=logger,
            temperature=config.temperature,
            top_p=config.top_p,
        )

    except openai.AuthenticationError:
        logger.exception('Authentication failed.')
    except openai.RateLimitError:
        logger.exception('Rate limit exceeded.')
    except openai.BadRequestError:
        logger.exception('Bad request.')
    except openai.APIConnectionError:
        logger.exception('Failed to connect to the API. Check network connection.')
    except openai.InternalServerError:
        logger.exception('Internal server error.')
    except openai.APITimeoutError:
        logger.exception('API timed out.')
    except openai.APIStatusError as e:
        logger.exception(f'API Status Error: Received status {e.status_code}.')
    except openai.APIError:
        logger.exception('An unexpected error occured in the API.')
    except Exception:
        logger.exception('An unexpected error occurred.')
    else:
        logger.info(f'LLM response:\n{output}')
        logger.info('Finished successfully.')
    finally:
        logger.info('Exiting')


def main(num_threads: int, multiport: bool):
    system_prompt = load_prompt('./prompts/system.txt')
    user_prompt = load_prompt('./prompts/user.txt')

    config = Config(
        engine=InferenceEngine.ollama,
        model=Model.qwen3_32b_cm,
        multiport=multiport,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        temperature=0.0,
        top_p=0.0,
        log_folder='./logs',
    )

    threads: list[threading.Thread] = []
    for id in range(num_threads):
        thread = threading.Thread(target=job, kwargs=dict(id=id, config=config))
        threads.append(thread)

    for thread in threads:
        thread.start()

    for thread in threads:
        thread.join()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-t', '--num-threads', type=int, required=True)
    args = parser.parse_args()

    main(num_threads=args.num_threads, multiport=True)
