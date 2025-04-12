import lightning as L
from lightning.app.components import ServeGradio

class StableDiffusionServer(ServeGradio):
    def __init__(self):
        super().__init__(
            cloud_build_config=L.BuildConfig(
                image="Dockerfile",  # Use your local Dockerfile
            ),
            cloud_compute=L.CloudCompute("gpu-fast", disk_size=50),
            exposed_ports=[7860],
        )
    
    def run(self):
        # The on_start.sh script will be automatically executed via ENTRYPOINT
        pass

app = L.LightningApp(StableDiffusionServer())