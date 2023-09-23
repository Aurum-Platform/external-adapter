import dotenv from 'dotenv';
import express, { Express, Request, Response } from "express";
import bodyParser = require("body-parser");
import axios, { AxiosResponse } from "axios";
import { log } from "console";

dotenv.config(); // Load environment variables from .env file

type Input = {
    id: number | string;
    data: {
        tokenAddress: string;
    };
};

type Output = {
    jobRunId: string | number;
    statusCode: number;
    data: {
        result: any;
    };
    error: string;
};

const PORT = process.env.PORT || 8080;
const API_KEY = process.env.API_KEY;

const app: Express = express();
app.use(bodyParser.json());
app.get("/", (req: Request, res: Response) => {
    res.send("FUCK IT WORKED");
});

app.post("/", async (req: Request, res: Response) => {
    const reqInput: Input = req.body;
    const url = `https://eth-mainnet.g.alchemy.com/nft/v2/${API_KEY}/getFloorPrice?contractAddress=${reqInput.data.tokenAddress}`;

    let resOutput: Output = {
        jobRunId: reqInput.id,
        statusCode: 200,
        data: {
            result: null,
        },
        error: '',
    };

    try {
        const apiResponse: AxiosResponse = await axios.get(url);
        resOutput.data = { result: apiResponse.data };
        resOutput.statusCode = apiResponse.status;
    } catch (error: any) {
        console.log("API Response Error: ", error);
        resOutput.error = error.message;
        resOutput.statusCode = error.response.status;
    }
    res.json(resOutput);
});

app.listen(PORT, () => {
    log('Listening to port: ', PORT);
    // log(resOutput);
});