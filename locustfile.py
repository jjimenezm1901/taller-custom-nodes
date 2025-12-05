import json
import random
import uuid
from locust import HttpUser, task, between

# Lista de preguntas
preguntas = [
"¿Qué cursos de informática avanzada ofrece Datapath?",
"¿Cómo puedo registrarme en un curso de Datapath?",
"¿Cuál es la duración del curso de Ingeniería de Datos?",
"¿Dónde encuentro el temario del curso de Arquitectura de Datos?",
"¿Qué requisitos necesito para inscribirme en Análisis de Datos?",
"¿El curso de DevOps Engineer incluye prácticas en la nube?",
"¿Qué nivel de conocimientos previos necesito para AI Engineer?",
"¿Cuál es el costo de los cursos en Datapath?",
"¿Existen promociones o descuentos en la matrícula?",
"¿Cómo puedo realizar el pago de un curso?",
"¿Puedo solicitar una factura al inscribirme?",
"¿Cuáles son las modalidades disponibles (online o presencial)?",
"¿Los cursos tienen certificación oficial?",
"¿Dónde puedo revisar las opiniones de otros estudiantes?",
"¿Cuál es el próximo inicio de clases en Datapath?",
"¿Puedo llevar más de un curso a la vez?",
"¿Datapath ofrece cursos para principiantes?",
"¿Qué herramientas de software se utilizan en el curso de Ingeniería de Datos?",
"¿Cómo obtengo asesoría para elegir el curso adecuado?",
"¿Hay clases grabadas en caso de no poder asistir en vivo?",
"¿Cuál es la diferencia entre Ingeniería de Datos y Arquitectura de Datos?",
"¿Qué oportunidades laborales puedo tener al terminar un curso?",
"¿Datapath entrega material de estudio digital?",
"¿Cómo puedo contactar a un asesor académico de Datapath?",
"¿Puedo recibir información detallada en mi correo electrónico?"
]

class PruebaAPI(HttpUser):
    wait_time = between(1, 2)  # Espera entre 1 y 3 segundos entre solicitudes
    host = "https://taller-n8n-capp-mode-queue.delightfultree-7f42d56b.eastus2.azurecontainerapps.io/webhook"


    @task
    def prueba_conversacion(self):
        """Simula una solicitud POST a la API de conversación con una pregunta aleatoria"""
        headers = {
            "Content-Type": "application/json",
            "token": "chatdfsdfsecret"
        }

        endpoint = "/datapath/conversation"
        pregunta_aleatoria = random.choice(preguntas)

        payload = {
            "question": pregunta_aleatoria,
            "metadata": {
                "userId": "test-user@test.com",
                "sessionId": str(uuid.uuid4()),
                "channelType": "whatsapp"
            },
            "configuration": {
                "config_params": {
                    "maxMinutes": "",
                    "temperature": 0.3,
                    "k_top_retrieval": 4,
                    "k_top_history": 5
                }
            }
        }

        response = self.client.post(endpoint, headers=headers, json=payload)

        # Validar respuesta y mostrar posibles errores
        if response.status_code != 200:
            print(f"Error {response.status_code}: {response.text}")
