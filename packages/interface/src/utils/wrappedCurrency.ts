import { ChainId, Currency, CurrencyAmount, DOGECHAIN, Token } from "@dogeswap/sdk-core";
import { getToken } from "../constants/tokens";

// TODO DOGESWAP: update this to use DS instead of DOGECHAIN and update currency to accept DS instead of DOGECHAIN
export function wrappedCurrency(currency: Currency | undefined, chainId: ChainId | undefined): Token | undefined {
    const wdc = getToken(chainId, "wdc");
    return chainId && currency === DOGECHAIN ? wdc : currency instanceof Token ? currency : undefined;
}

export function wrappedCurrencyAmount(
    currencyAmount: CurrencyAmount | undefined,
    chainId: ChainId | undefined,
): CurrencyAmount | undefined {
    const token = currencyAmount && chainId ? wrappedCurrency(currencyAmount.currency, chainId) : undefined;
    return token && currencyAmount ? new CurrencyAmount(token, currencyAmount.raw) : undefined;
}

export function unwrappedToken(token: Token): Currency {
    const wdc = getToken(token.chainId, "wdc");
    if (wdc != undefined && token.equals(wdc)) return DOGECHAIN;
    return token;
}
