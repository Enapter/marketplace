# Alarm sensor connected to Sonoff RF Bridge

This [Enapter Device Blueprint](https://github.com/Enapter/marketplace#blue_book-enapter-device-blueprints) integrates an **Alarm sensor connected to Sonoff RF Bridge** via [eWelink REST API Server](https://github.com/DoganM95/Ewelink-Rest-Api-Server). The Blueprint is running on [Enapter Virtual UCM](https://handbook.enapter.com/software/software.html#%F0%9F%92%8E-virtual-ucm).

If you have more than one alarm (like in this blueprint) you should create as many [vUCMS](https://go.enapter.com/create-vucm) as a number of your alarms and [upload this blueprint](https://go.enapter.com/developers-upload-blueprint) to every vUCM.

## Requirements

1. **eWelink account**
  
    You require to have **email** and **password** used for login as well as **region**.

    The **eWelink** account can be created in the [eWelink Mobile App](https://sonoff.tech/ewelink/).

2. **Sonoff Device ID**
    You can find it in the eWelink app:
  
    1. Tap on Device.
    2. Click ... in top right corner.

        <img src="./.assets/more.jpg" alt="more" width="25%" />

    3. Scroll down to Device ID. Write it down for future use.

        <img src="./.assets/device_id.jpg" alt="device_id" width="25%" />

3. **Latest version of Enapter Gateway Software**

    Enapter Gateway Software must support Virtual UCM and Docker containers runtime.

## Running eWelink REST API Server

This Blueprint is using **eWelink REST API Server**. For more details visit [its page at GitHub](https://github.com/DoganM95/Ewelink-Rest-Api-Server) and [Docker Hub](https://hub.docker.com/r/doganm95/ewelink-rest-api-server)

At the moment of writing the instruction the original eWelink REST API server has no support for several channel devices but you can get a [patch](https://github.com/nkrasko/Ewelink-Rest-Api-Server).

The REST API is an intermediate service which from one side connects to eWelink client API (for example eWelink mobile application) and on the other side provides HTTP endpoint where you can get data of your devices in JSON format or execute commands for switches.

The beauty of this solution is a possibility to use Enapter Energy Management toolkit and exisitng eWelink service.

In this example we will build our own container.

1. Clone repository

    ```zsh
    git clone https://github.com/nkrasko/Ewelink-Rest-Api-Server
    cd Ewelink-Rest-Api-Server
    ```

2. Build container

    ```zsh
    docker build -t nkrasko/ewelink-rest-api-server -f ./docker/Dockerfile .
    ```

3. Run docker container

    ```zsh
    docker run -d --restart unless-stopped \
          -p LOCAL_TCP_PORT:3000 \
          -e 'EWELINK_USERNAME=EMAIL' \
          -e 'EWELINK_PASSWORD=PASSWORD' \
          -e 'EWELINK_REGION=REGION' \
          -e 'SERVER_MODE=dev' \
          nkrasko/ewelink-rest-api-server
    ```

    Put the correct values for:

    - **EMAIL** - your eWelink email, for example, test@test.com
    - **PASSWORD** - your eWelink password
    - **REGION** - your eWelink Region:
      - Mainland China: CN
      - Asia: AS
      - Americas: US
      - Europe: EU
    - **LOCAL_TCP_PORT**: any free TCP port on which HTTP server will be listening. This port will be needed for Virtual UCM configuration in next steps. For example, `8081`.

3. Check docker container is up and healthy by running command:

    ```zsh
    docker ps
    ```

    You should see something like:

    ```zsh
    CONTAINER ID   IMAGE                              COMMAND                  CREATED          STATUS          PORTS                    NAMES
    6261c5dd833f   nkrasko/ewelink-rest-api-server   "docker-entrypoint.s…"   33 minutes ago   Up 33 minutes   0.0.0.0:8081->3000/tcp   hungry_lewin
    ```

​    In above example, the docker container is running on TCP port 8081.

4. Check your API provides valid response with CURL from host where docker container runs:

    ```zsh
    curl http://127.0.0.1:8081
    ```

    You should get valid JSON as response.

If everything is fine you are ready to connect your device to Enapter Cloud!

## Connect to Enapter

1. Sign up to the Enapter Cloud using the [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).

2. Use the [Enapter Gateway](https://handbook.enapter.com/software/gateway/2.0.0/setup/) to run the Virtual UCM. If you are running eWelink REST API server on diiferent computer, ensure it is available from the Enapter Gateway.

3. Create the [Enapter Virtual UCM](https://handbook.enapter.com/software/software.html#%F0%9F%92%8E-virtual-ucm).

4. Upload thie Blueprint using [Enapter Marketplace](https://marketplace.enapter.com) on your mobile device. Advanced users can upload using Web IDE or CLI by following [Developer Documentation](https://developers.enapter.com/docs/tutorial/uploading-blueprint/).

5. As soon as Blueprint will start the `Module Not Configured` event will be triggered.

6. Navigate to `Settings` (<img src="./.assets/settings.jpg" alt="settings" width="5%" />).

7. Click `Commands`.

8. In the  `Settings` section of the `Commands` screen click on `Main Configuration` command in the Enapter mobile or Web app to set main settings for your Virtual UCM:

    <img src="./.assets/main_settings.jpg" alt="main_settings" width="25%" />

    You need to set the following parameters you got during previous steps:

    - IP Address of eWelink REST API server;

    - IP Port;

    - Device ID;

    - Remote Number.

9. Press `Run` button

The status data should be available on your **Alarm sensor connected to Sonoff RF Bridge** dashboard.

## References

- [Sonoff RF Bridge product page](https://sonoff.tech/product/smart-home-security/rf-bridge/)

- [Docker image for eWelink REST API server](https://hub.docker.com/r/doganm95/ewelink-rest-api-server)

- [eWelink REST API server Github repository](https://github.com/DoganM95/Ewelink-rest-api-server)
