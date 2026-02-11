use rustler::{Env, Term, NifResult, Error, Encoder, NifStruct};
use std::collections::HashMap;

mod atoms {
    rustler::atoms! {
        ok,
        error,
        timeout,
        network_error,
        invalid_url,
    }
}

#[derive(Debug, NifStruct)]
#[module = "RustReq.Options"]
struct HttpOptions {
    timeout_ms: Option<u64>,
    proxy: Option<String>,
    follow_redirects: Option<bool>,
    max_redirects: Option<usize>,
}

impl Default for HttpOptions {
    fn default() -> Self {
        HttpOptions {
            timeout_ms: Some(30000),
            proxy: None,
            follow_redirects: Some(true),
            max_redirects: Some(10),
        }
    }
}

#[derive(Debug)]
struct HttpResponse {
    status: u16,
    headers: HashMap<String, String>,
    body: String,
}

impl Encoder for HttpResponse {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let headers_map: Vec<(String, String)> = self.headers.clone().into_iter().collect();

        (
            atoms::ok(),
            (
                self.status,
                headers_map,
                self.body.clone(),
            )
        ).encode(env)
    }
}

fn build_client(options: &HttpOptions) -> Result<reqwest::blocking::Client, Box<dyn std::error::Error>> {
    let mut builder = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_millis(options.timeout_ms.unwrap_or(30000)));

    if let Some(proxy_url) = &options.proxy {
        builder = builder.proxy(reqwest::Proxy::all(proxy_url)?);
    }

    if let Some(follow) = options.follow_redirects {
        if !follow {
            builder = builder.redirect(reqwest::redirect::Policy::none());
        } else if let Some(max) = options.max_redirects {
            builder = builder.redirect(reqwest::redirect::Policy::limited(max));
        }
    }

    Ok(builder.build()?)
}

fn build_async_client(options: &HttpOptions) -> Result<reqwest::Client, Box<dyn std::error::Error>> {
    let mut builder = reqwest::Client::builder()
        .timeout(std::time::Duration::from_millis(options.timeout_ms.unwrap_or(30000)));

    if let Some(proxy_url) = &options.proxy {
        builder = builder.proxy(reqwest::Proxy::all(proxy_url)?);
    }

    if let Some(follow) = options.follow_redirects {
        if !follow {
            builder = builder.redirect(reqwest::redirect::Policy::none());
        } else if let Some(max) = options.max_redirects {
            builder = builder.redirect(reqwest::redirect::Policy::limited(max));
        }
    }

    Ok(builder.build()?)
}

// Synchronous HTTP GET
#[rustler::nif]
fn http_get(url: String, headers: Vec<(String, String)>, options: HttpOptions) -> NifResult<HttpResponse> {
    let client = build_client(&options)
        .map_err(|e| Error::Term(Box::new(format!("Client error: {}", e))))?;

    let mut request = client.get(&url);

    for (key, value) in headers {
        request = request.header(key, value);
    }

    let response = request
        .send()
        .map_err(|e| {
            if e.is_timeout() {
                Error::Atom("timeout")
            } else if e.is_connect() {
                Error::Atom("network_error")
            } else {
                Error::Term(Box::new(format!("Request error: {}", e)))
            }
        })?;

    let status = response.status().as_u16();
    let headers_map: HashMap<String, String> = response
        .headers()
        .iter()
        .map(|(k, v)| (k.to_string(), v.to_str().unwrap_or("").to_string()))
        .collect();

    let body = response.text()
        .map_err(|e| Error::Term(Box::new(format!("Body error: {}", e))))?;

    Ok(HttpResponse {
        status,
        headers: headers_map,
        body,
    })
}

// Synchronous HTTP POST
#[rustler::nif]
fn http_post(url: String, headers: Vec<(String, String)>, body: String, options: HttpOptions) -> NifResult<HttpResponse> {
    let client = build_client(&options)
        .map_err(|e| Error::Term(Box::new(format!("Client error: {}", e))))?;

    let mut request = client.post(&url).body(body);

    for (key, value) in headers {
        request = request.header(key, value);
    }

    let response = request
        .send()
        .map_err(|e| {
            if e.is_timeout() {
                Error::Atom("timeout")
            } else if e.is_connect() {
                Error::Atom("network_error")
            } else {
                Error::Term(Box::new(format!("Request error: {}", e)))
            }
        })?;

    let status = response.status().as_u16();
    let headers_map: HashMap<String, String> = response
        .headers()
        .iter()
        .map(|(k, v)| (k.to_string(), v.to_str().unwrap_or("").to_string()))
        .collect();

    let body = response.text()
        .map_err(|e| Error::Term(Box::new(format!("Body error: {}", e))))?;

    Ok(HttpResponse {
        status,
        headers: headers_map,
        body,
    })
}

// Async HTTP GET (for concurrent requests)
#[rustler::nif]
fn http_get_async(url: String, headers: Vec<(String, String)>, options: HttpOptions) -> NifResult<HttpResponse> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| Error::Term(Box::new(format!("Runtime error: {}", e))))?;

    rt.block_on(async {
        let client = build_async_client(&options)
            .map_err(|e| Error::Term(Box::new(format!("Client error: {}", e))))?;

        let mut request = client.get(&url);

        for (key, value) in headers {
            request = request.header(key, value);
        }

        let response = request
            .send()
            .await
            .map_err(|e| {
                if e.is_timeout() {
                    Error::Atom("timeout")
                } else if e.is_connect() {
                    Error::Atom("network_error")
                } else {
                    Error::Term(Box::new(format!("Request error: {}", e)))
                }
            })?;

        let status = response.status().as_u16();
        let headers_map: HashMap<String, String> = response
            .headers()
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_str().unwrap_or("").to_string()))
            .collect();

        let body = response.text()
            .await
            .map_err(|e| Error::Term(Box::new(format!("Body error: {}", e))))?;

        Ok(HttpResponse {
            status,
            headers: headers_map,
            body,
        })
    })
}

// Async HTTP POST
#[rustler::nif]
fn http_post_async(url: String, headers: Vec<(String, String)>, body: String, options: HttpOptions) -> NifResult<HttpResponse> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| Error::Term(Box::new(format!("Runtime error: {}", e))))?;

    rt.block_on(async {
        let client = build_async_client(&options)
            .map_err(|e| Error::Term(Box::new(format!("Client error: {}", e))))?;

        let mut request = client.post(&url).body(body);

        for (key, value) in headers {
            request = request.header(key, value);
        }

        let response = request
            .send()
            .await
            .map_err(|e| {
                if e.is_timeout() {
                    Error::Atom("timeout")
                } else if e.is_connect() {
                    Error::Atom("network_error")
                } else {
                    Error::Term(Box::new(format!("Request error: {}", e)))
                }
            })?;

        let status = response.status().as_u16();
        let headers_map: HashMap<String, String> = response
            .headers()
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_str().unwrap_or("").to_string()))
            .collect();

        let body = response.text()
            .await
            .map_err(|e| Error::Term(Box::new(format!("Body error: {}", e))))?;

        Ok(HttpResponse {
            status,
            headers: headers_map,
            body,
        })
    })
}

// Batch async requests for maximum throughput
#[rustler::nif]
fn http_get_batch<'a>(env: Env<'a>, urls: Vec<String>, headers: Vec<(String, String)>, options: HttpOptions) -> NifResult<Term<'a>> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| Error::Term(Box::new(format!("Runtime error: {}", e))))?;

    rt.block_on(async {
        let client = build_async_client(&options)
            .map_err(|e| Error::Term(Box::new(format!("Client error: {}", e))))?;

        let tasks: Vec<_> = urls.into_iter().map(|url| {
            let client = client.clone();
            let headers = headers.clone();

            tokio::spawn(async move {
                let mut request = client.get(&url);

                for (key, value) in headers {
                    request = request.header(key, value);
                }

                match request.send().await {
                    Ok(response) => {
                        let status = response.status().as_u16();
                        let headers_map: HashMap<String, String> = response
                            .headers()
                            .iter()
                            .map(|(k, v)| (k.to_string(), v.to_str().unwrap_or("").to_string()))
                            .collect();

                        match response.text().await {
                            Ok(body) => Ok(HttpResponse {
                                status,
                                headers: headers_map,
                                body,
                            }),
                            Err(e) => Err(format!("Body error: {}", e)),
                        }
                    }
                    Err(e) => Err(format!("Request error: {}", e)),
                }
            })
        }).collect();

        let mut results = Vec::new();
        for task in tasks {
            match task.await {
                Ok(Ok(response)) => {
                    // Encode as {:ok, {status, headers, body}}
                    let headers_list: Vec<(String, String)> = response.headers.clone().into_iter().collect();
                    results.push((atoms::ok(), (response.status, headers_list, response.body)).encode(env));
                }
                Ok(Err(error_msg)) => {
                    // Encode as {:error, reason}
                    results.push((atoms::error(), error_msg).encode(env));
                }
                Err(e) => {
                    // Encode as {:error, reason}
                    results.push((atoms::error(), format!("Task error: {}", e)).encode(env));
                }
            }
        }

        Ok(results.encode(env))
    })
}

rustler::init!("Elixir.RustReq.Native");
